import Foundation
import SwiftData
import Testing
@testable import Caliber__DEV_

@MainActor
@Suite("Daily progress check-ins")
struct ProgressEntryEditorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(day: Int = 8, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([ProgressEntry.self, ProgressPhoto.self, WeightEntry.self])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private func photos() -> [ProgressPhotoDraft] {
        [ProgressPhotoDraft(imageData: Data([1, 2, 3])), ProgressPhotoDraft(imageData: Data([4, 5, 6]))]
    }

    private func makeFixture() throws -> (
        container: ModelContainer, context: ModelContext,
        entry: ProgressEntry, standaloneWeight: WeightEntry
    ) {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        // This old-style weigh-in is deliberately on the same day as the check-in.
        let standalone = WeightEntry(date: date(hour: 7), weightInPounds: 201)
        context.insert(standalone)
        let entry = try ProgressEntryEditor.save(
            date: date(), weightInPounds: 200.5, notes: "Original note", photos: photos(),
            in: context, calendar: calendar
        )
        return (container, context, entry, standalone)
    }

    @Test("A check-in persists its day, trimmed note, owned weight, and ordered photos")
    func createPersistsAllFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let drafts = photos()
        let entry = try ProgressEntryEditor.save(
            date: date(hour: 18), weightInPounds: 180.25, notes: "  Feeling stronger \n",
            photos: drafts, in: context, calendar: calendar
        )
        let readContext = ModelContext(container)
        let stored = try #require(readContext.fetch(FetchDescriptor<ProgressEntry>()).first)
        #expect(stored.id == entry.id)
        #expect(stored.date == calendar.startOfDay(for: date()))
        #expect(stored.notes == "Feeling stronger")
        #expect(stored.weightEntry?.weightInPounds == 180.25)
        #expect(stored.weightEntry?.date == stored.date)
        #expect(stored.weightEntry?.progressEntry?.id == stored.id)
        #expect(stored.sortedPhotos.map(\.id) == drafts.map(\.id))
        #expect(stored.sortedPhotos.map(\.sortOrder) == [0, 1])
        #expect(stored.sortedPhotos.map(\.imageData) == drafts.map(\.imageData))
        #expect(stored.photos.allSatisfy { $0.progressEntry?.id == stored.id })
    }

    @Test("Each optional field can be the only content", arguments: ["weight", "notes", "photos"])
    func savesIndividualOptionalFields(field: String) throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = try ProgressEntryEditor.save(
            date: date(), weightInPounds: field == "weight" ? 165 : nil,
            notes: field == "notes" ? "A note" : "",
            photos: field == "photos" ? photos() : [], in: context, calendar: calendar
        )
        #expect((entry.weightEntry != nil) == (field == "weight"))
        #expect((!entry.notes.isEmpty) == (field == "notes"))
        #expect((!entry.photos.isEmpty) == (field == "photos"))
        #expect(try context.fetchCount(FetchDescriptor<ProgressEntry>()) == 1)
    }

    @Test("Photos, order, weight, and notes survive reopening a disk-backed store")
    func diskStorePreservesPhotoDataAcrossContainers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProgressPersistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("progress.store")
        let schema = Schema([ProgressEntry.self, ProgressPhoto.self, WeightEntry.self])
        func diskContainer() throws -> ModelContainer {
            let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: configuration)
        }

        // Use substantial, distinct blobs so this exercises the external-storage
        // attribute as well as the small in-memory fixtures used by other tests.
        let drafts = [
            ProgressPhotoDraft(imageData: Data((0..<(512 * 1024)).map { UInt8(truncatingIfNeeded: $0 * 31 + 17) })),
            ProgressPhotoDraft(imageData: Data((0..<(768 * 1024)).map { UInt8(truncatingIfNeeded: ($0 >> 3) ^ $0) }))
        ]
        let entryID: UUID
        do {
            let container = try diskContainer()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let entry = try ProgressEntryEditor.save(
                date: date(hour: 19), weightInPounds: 179.75,
                notes: "  Photos after a walk  ", photos: drafts,
                in: context, calendar: calendar
            )
            entryID = entry.id
        }

        // This container is newly created from the on-disk URL; no model or
        // context from the writer is reused to satisfy the assertions.
        do {
            let reopenedContainer = try diskContainer()
            let reopenedContext = ModelContext(reopenedContainer)
            let entry = try #require(reopenedContext.fetch(FetchDescriptor<ProgressEntry>()).first)
            #expect(entry.id == entryID)
            #expect(entry.date == calendar.startOfDay(for: date()))
            #expect(entry.notes == "Photos after a walk")
            #expect(entry.weightEntry?.weightInPounds == 179.75)
            #expect(entry.weightEntry?.date == entry.date)
            #expect(entry.weightEntry?.progressEntry?.id == entryID)
            #expect(entry.sortedPhotos.map(\.id) == drafts.map(\.id))
            #expect(entry.sortedPhotos.map(\.sortOrder) == [0, 1])
            #expect(entry.sortedPhotos.map(\.imageData) == drafts.map(\.imageData))
            #expect(entry.photos.allSatisfy { $0.progressEntry?.id == entryID })
        }
    }

    @Test("Empty content, invalid weight, and malformed photo drafts do not create rows")
    func invalidInputDoesNotMutateStore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        #expect(throws: ProgressEntryEditor.EditError.self) {
            try ProgressEntryEditor.save(date: date(), weightInPounds: nil, notes: " \n ", photos: [], in: context, calendar: calendar)
        }
        for invalid in [0, -5, Double.nan, Double.infinity] {
            #expect(throws: ProgressEntryEditor.EditError.self) {
                try ProgressEntryEditor.save(date: date(), weightInPounds: invalid, notes: "Still invalid", photos: [], in: context, calendar: calendar)
            }
        }
        let repeated = ProgressPhotoDraft(imageData: Data([1]))
        let invalidDrafts = [
            [ProgressPhotoDraft(imageData: Data())],
            [repeated, repeated],
            (0..<7).map { ProgressPhotoDraft(imageData: Data([UInt8($0)])) }
        ]
        for drafts in invalidDrafts {
            #expect(throws: ProgressEntryEditor.EditError.self) {
                try ProgressEntryEditor.save(date: date(), weightInPounds: nil, notes: "", photos: drafts, in: context, calendar: calendar)
            }
        }
        #expect(try context.fetchCount(FetchDescriptor<ProgressEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ProgressPhoto>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WeightEntry>()) == 0)
    }

    @Test("Only one check-in is allowed per calendar day, including a daylight-saving transition")
    func rejectsDuplicateDay() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let first = try ProgressEntryEditor.save(
            date: date(hour: 0, minute: 30), weightInPounds: nil, notes: "Morning", photos: [], in: context, calendar: calendar
        )
        #expect(throws: ProgressEntryEditor.EditError.self) {
            try ProgressEntryEditor.save(date: date(hour: 23, minute: 45), weightInPounds: 180, notes: "Evening", photos: [], in: context, calendar: calendar)
        }
        let second = try ProgressEntryEditor.save(
            date: date(day: 9, hour: 0, minute: 1), weightInPounds: nil, notes: "Next day", photos: [], in: context, calendar: calendar
        )
        #expect(throws: ProgressEntryEditor.EditError.self) {
            try ProgressEntryEditor.save(entry: second, date: date(hour: 17), weightInPounds: nil, notes: "Move", photos: [], in: context, calendar: calendar)
        }
        #expect(first.notes == "Morning")
        #expect(second.notes == "Next day")
        #expect(second.date == calendar.startOfDay(for: date(day: 9)))
        #expect(try context.fetchCount(FetchDescriptor<ProgressEntry>()) == 2)
    }

    @Test("Editing preserves entry, weight and photo IDs while persisting a new photo order")
    func editPreservesIDsAndOrder() throws {
        let fixture = try makeFixture()
        let entryID = fixture.entry.id
        let weightID = fixture.entry.weightEntry?.id
        let drafts = fixture.entry.sortedPhotos.reversed().map { ProgressPhotoDraft(id: $0.id, imageData: $0.imageData) }
        let edited = try ProgressEntryEditor.save(
            entry: fixture.entry, date: date(day: 9, hour: 18), weightInPounds: 199.25,
            notes: "  Updated  ", photos: drafts, in: fixture.context, calendar: calendar
        )
        #expect(edited.id == entryID)
        #expect(edited.weightEntry?.id == weightID)
        #expect(edited.weightEntry?.date == edited.date)
        #expect(edited.weightEntry?.weightInPounds == 199.25)
        let readContext = ModelContext(fixture.container)
        let stored = try #require(readContext.fetch(FetchDescriptor<ProgressEntry>()).first)
        #expect(stored.sortedPhotos.map(\.id) == drafts.map(\.id))
        #expect(stored.sortedPhotos.map(\.sortOrder) == [0, 1])
        #expect(stored.notes == "Updated")
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressEntry>()) == 1)
        #expect(try readContext.fetchCount(FetchDescriptor<WeightEntry>()) == 2)
    }

    @Test("Removing weight and photos deletes only those owned by the edited check-in")
    func editRemovesOwnedFields() throws {
        let fixture = try makeFixture()
        try ProgressEntryEditor.save(
            entry: fixture.entry, date: date(), weightInPounds: nil,
            notes: "Notes only now", photos: [], in: fixture.context, calendar: calendar
        )
        let readContext = ModelContext(fixture.container)
        let stored = try #require(readContext.fetch(FetchDescriptor<ProgressEntry>()).first)
        #expect(stored.weightEntry == nil)
        #expect(stored.photos.isEmpty)
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressPhoto>()) == 0)
        let weights = try readContext.fetch(FetchDescriptor<WeightEntry>())
        #expect(weights.count == 1)
        #expect(weights.first?.id == fixture.standaloneWeight.id)
        #expect(weights.first?.weightInPounds == 201)
        #expect(weights.first?.progressEntry == nil)
    }

    @Test("Deleting a check-in cascades to its owned weight/photos and preserves standalone weigh-ins")
    func deleteCascadesOnlyOwnedRows() throws {
        let fixture = try makeFixture()
        try ProgressEntryEditor.delete(entry: fixture.entry, in: fixture.context)
        let readContext = ModelContext(fixture.container)
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressEntry>()) == 0)
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressPhoto>()) == 0)
        let weights = try readContext.fetch(FetchDescriptor<WeightEntry>())
        #expect(weights.count == 1)
        #expect(weights.first?.id == fixture.standaloneWeight.id)
    }

    private enum SaveFailure: Error { case diskFull }

    @Test("A failed create leaves no progress rows and preserves unrelated pending work")
    func failedCreateCleansUp() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let standalone = WeightEntry(date: date(), weightInPounds: 190)
        context.insert(standalone)
        try context.save()
        standalone.weightInPounds = 189
        #expect(throws: SaveFailure.self) {
            try ProgressEntryEditor.save(
                date: date(), weightInPounds: 185, notes: "Attempt", photos: photos(),
                in: context, calendar: calendar, persist: { _ in throw SaveFailure.diskFull }
            )
        }
        try context.save()
        let readContext = ModelContext(container)
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressEntry>()) == 0)
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressPhoto>()) == 0)
        let weights = try readContext.fetch(FetchDescriptor<WeightEntry>())
        #expect(weights.count == 1)
        #expect(weights.first?.weightInPounds == 189)
    }

    @Test("A failed edit restores removed data, order, and relationships without discarding other work")
    func failedEditRestoresOriginalEntry() throws {
        let fixture = try makeFixture()
        let originalPhotos = fixture.entry.sortedPhotos.map { ProgressPhotoDraft(id: $0.id, imageData: $0.imageData) }
        let weightID = fixture.entry.weightEntry?.id
        fixture.standaloneWeight.weightInPounds = 202
        let modifiedPhoto = ProgressPhotoDraft(id: originalPhotos[0].id, imageData: Data([9]))
        #expect(throws: SaveFailure.self) {
            try ProgressEntryEditor.save(
                entry: fixture.entry, date: date(day: 9), weightInPounds: nil, notes: "Not saved",
                photos: [modifiedPhoto, ProgressPhotoDraft(imageData: Data([8]))],
                in: fixture.context, calendar: calendar, persist: { _ in throw SaveFailure.diskFull }
            )
        }
        try fixture.context.save()
        let readContext = ModelContext(fixture.container)
        let stored = try #require(readContext.fetch(FetchDescriptor<ProgressEntry>()).first)
        #expect(stored.date == calendar.startOfDay(for: date()))
        #expect(stored.notes == "Original note")
        #expect(stored.weightEntry?.id == weightID)
        #expect(stored.weightEntry?.weightInPounds == 200.5)
        #expect(stored.weightEntry?.progressEntry?.id == stored.id)
        #expect(stored.sortedPhotos.map(\.id) == originalPhotos.map(\.id))
        #expect(stored.sortedPhotos.map(\.imageData) == originalPhotos.map(\.imageData))
        #expect(stored.photos.allSatisfy { $0.progressEntry?.id == stored.id })
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressPhoto>()) == 2)
        let unrelated = try #require(readContext.fetch(FetchDescriptor<WeightEntry>()).first { $0.id == fixture.standaloneWeight.id })
        #expect(unrelated.weightInPounds == 202)
    }

    @Test("A failed edit adding weight and photos leaves a notes-only entry unchanged")
    func failedEditRemovesNewChildren() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let entry = try ProgressEntryEditor.save(
            date: date(), weightInPounds: nil, notes: "Notes only", photos: [], in: context, calendar: calendar
        )
        #expect(throws: SaveFailure.self) {
            try ProgressEntryEditor.save(
                entry: entry, date: date(day: 9), weightInPounds: 175, notes: "Attempt", photos: photos(),
                in: context, calendar: calendar, persist: { _ in throw SaveFailure.diskFull }
            )
        }
        try context.save()
        let readContext = ModelContext(container)
        let stored = try #require(readContext.fetch(FetchDescriptor<ProgressEntry>()).first)
        #expect(stored.notes == "Notes only")
        #expect(stored.date == calendar.startOfDay(for: date()))
        #expect(stored.weightEntry == nil)
        #expect(stored.photos.isEmpty)
        #expect(try readContext.fetchCount(FetchDescriptor<WeightEntry>()) == 0)
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressPhoto>()) == 0)
    }

    @Test("A failed delete restores owned rows and permits a later successful deletion")
    func failedDeleteRestoresRelationships() throws {
        let fixture = try makeFixture()
        let entryID = fixture.entry.id
        let weightID = fixture.entry.weightEntry?.id
        let photoIDs = fixture.entry.sortedPhotos.map(\.id)
        fixture.standaloneWeight.weightInPounds = 202
        #expect(throws: SaveFailure.self) {
            try ProgressEntryEditor.delete(entry: fixture.entry, in: fixture.context, persist: { _ in throw SaveFailure.diskFull })
        }
        try fixture.context.save()
        let readContext = ModelContext(fixture.container)
        let stored = try #require(readContext.fetch(FetchDescriptor<ProgressEntry>()).first)
        #expect(stored.id == entryID)
        let restoredEntryCount = try readContext.fetchCount(FetchDescriptor<ProgressEntry>())
        let restoredWeightCount = try readContext.fetchCount(FetchDescriptor<WeightEntry>())
        #expect(restoredEntryCount == 1)
        #expect(restoredWeightCount == 2)
        #expect(stored.weightEntry?.id == weightID)
        #expect(stored.weightEntry?.progressEntry?.id == entryID)
        #expect(stored.sortedPhotos.map(\.id) == photoIDs)
        #expect(stored.photos.allSatisfy { $0.progressEntry?.id == entryID })
        #expect(try readContext.fetchCount(FetchDescriptor<ProgressPhoto>()) == 2)
        #expect(fixture.standaloneWeight.weightInPounds == 202)

        try ProgressEntryEditor.delete(entry: fixture.entry, in: fixture.context)
        let afterDelete = ModelContext(fixture.container)
        let entryCount = try afterDelete.fetchCount(FetchDescriptor<ProgressEntry>())
        let photoCount = try afterDelete.fetchCount(FetchDescriptor<ProgressPhoto>())
        let weightCount = try afterDelete.fetchCount(FetchDescriptor<WeightEntry>())
        #expect(entryCount == 0)
        #expect(photoCount == 0)
        #expect(weightCount == 1)
    }
}
