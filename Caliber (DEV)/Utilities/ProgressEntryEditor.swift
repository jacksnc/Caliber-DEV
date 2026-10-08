import Foundation
import SwiftData

/// Validates and saves a daily check-in without changing unrelated weigh-ins.
@MainActor
enum ProgressEntryEditor {
    static let maximumPhotos = 6

    enum EditError: LocalizedError {
        case emptyEntry
        case invalidWeight
        case invalidPhotos
        case tooManyPhotos
        case duplicateDay
        case invalidDate

        var errorDescription: String? {
            switch self {
            case .emptyEntry: "Add a weight, note, or photo before saving."
            case .invalidWeight: "Enter a valid weight greater than zero."
            case .invalidPhotos: "One or more photos couldn't be saved. Remove them and try again."
            case .tooManyPhotos: "You can add up to six photos to one check-in."
            case .duplicateDay: "You already have a check-in for this day. Edit that check-in instead."
            case .invalidDate: "Choose a valid date for this check-in."
            }
        }
    }

    @discardableResult
    static func save(
        entry: ProgressEntry? = nil,
        date: Date,
        weightInPounds: Double?,
        notes: String,
        photos: [ProgressPhotoDraft],
        in context: ModelContext,
        calendar: Calendar = .current,
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> ProgressEntry {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let weightInPounds, !weightInPounds.isFinite || weightInPounds <= 0 {
            throw EditError.invalidWeight
        }
        guard photos.count <= maximumPhotos else { throw EditError.tooManyPhotos }
        guard photos.allSatisfy({ !$0.imageData.isEmpty }), Set(photos.map(\.id)).count == photos.count else {
            throw EditError.invalidPhotos
        }
        guard weightInPounds != nil || !trimmedNotes.isEmpty || !photos.isEmpty else { throw EditError.emptyEntry }
        guard date.timeIntervalSinceReferenceDate.isFinite else { throw EditError.invalidDate }
        let day = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day), nextDay > day else {
            throw EditError.invalidDate
        }
        let descriptor = FetchDescriptor<ProgressEntry>(predicate: #Predicate { $0.date >= day && $0.date < nextDay })
        let sameDayEntries = try context.fetch(descriptor)
        guard sameDayEntries.allSatisfy({ $0.id == entry?.id }) else { throw EditError.duplicateDay }

        // All mutations below are synchronous on the main actor. First save any
        // existing work so rollback can safely undo only this operation if it fails.
        if context.hasChanges { try context.save() }
        let savedEntry = entry ?? ProgressEntry(date: day)
        if entry == nil { context.insert(savedEntry) }
        savedEntry.date = day
        savedEntry.notes = trimmedNotes

        if let weightInPounds {
            let weight = savedEntry.weightEntry ?? WeightEntry(date: day, weightInPounds: weightInPounds)
            context.insert(weight)
            weight.date = day
            weight.weightInPounds = weightInPounds
            savedEntry.weightEntry = weight
            weight.progressEntry = savedEntry
        } else if let removedWeight = savedEntry.weightEntry {
            savedEntry.weightEntry = nil
            context.delete(removedWeight)
        }

        let originalPhotos = savedEntry.photos
        let originalsByID = Dictionary(uniqueKeysWithValues: originalPhotos.map { ($0.id, $0) })
        let updatedPhotos = photos.enumerated().map { index, draft in
            let photo = originalsByID[draft.id]
                ?? ProgressPhoto(id: draft.id, imageData: draft.imageData, sortOrder: index)
            context.insert(photo)
            photo.imageData = draft.imageData
            photo.sortOrder = index
            return photo
        }
        savedEntry.photos = updatedPhotos
        updatedPhotos.forEach { $0.progressEntry = savedEntry }
        let keptPhotoIDs = Set(photos.map(\.id))
        for oldPhoto in originalPhotos where !keptPhotoIDs.contains(oldPhoto.id) {
            context.delete(oldPhoto)
        }

        do {
            try persist(context)
            return savedEntry
        } catch {
            context.rollback()
            throw error
        }
    }

    static func delete(
        entry: ProgressEntry,
        in context: ModelContext,
        persist: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        // A saved checkpoint preserves unrelated edits while SwiftData's rollback
        // restores the entire deleted graph, including photo data and inverse links.
        if context.hasChanges { try context.save() }
        context.delete(entry)
        do {
            try persist(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
