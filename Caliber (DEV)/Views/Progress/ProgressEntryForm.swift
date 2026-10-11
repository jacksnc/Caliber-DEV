import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// All edits stay in local state until Save. Removing a photo or changing a
/// weight here cannot change an existing check-in when the user taps Cancel.
struct ProgressEntryForm: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("progressWeightUnit") private var weightUnitRawValue = WeightUnit.pounds.rawValue

    private let entry: ProgressEntry?
    private let hidesWeight: Bool
    @State private var selectedDate: Date
    @State private var photos: [ProgressPhotoDraft]
    @State private var weightText = ""
    @State private var selectedUnit: WeightUnit = .pounds
    @State private var notes: String
    @State private var didLoadWeight = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var importTask: Task<Void, Never>?
    @State private var isImportingPhotos = false
    @State private var photoError: String?
    @State private var saveError: String?

    init(entry: ProgressEntry? = nil, date: Date = Date(), hidesWeight: Bool = false) {
        self.hidesWeight = hidesWeight
        self.entry = entry
        _selectedDate = State(initialValue: entry?.date ?? date)
        _notes = State(initialValue: entry?.notes ?? "")
        _photos = State(initialValue: entry?.sortedPhotos.map {
            ProgressPhotoDraft(id: $0.id, imageData: $0.imageData)
        } ?? [])
    }

    private var unit: WeightUnit {
        selectedUnit
    }

    private var hasWeightText: Bool {
        !weightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var weightInPounds: Double? {
        if hidesWeight { return entry?.weightEntry?.weightInPounds }
        guard let value = NutritionInput.quantity(weightText, locale: locale) else { return nil }
        let pounds = unit.toPounds(value)
        return pounds.isFinite && pounds > 0 ? pounds : nil
    }

    private var canSave: Bool {
        !isImportingPhotos
            && (!hasWeightText || weightInPounds != nil)
            && (!photos.isEmpty || weightInPounds != nil
                || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section("Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .accessibilityIdentifier("progressDate")
                }

                if !hidesWeight {
                Section {
                    LabeledContent("Weight") {
                        TextField("Optional", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Weight")
                            .accessibilityIdentifier("progressWeight")
                    }
                    Picker("Unit", selection: Binding(get: { unit }, set: changeUnit)) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Weight unit")
                    if hasWeightText && weightInPounds == nil {
                        Text("Enter a weight greater than zero, or leave it blank.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Weight (optional)")
                }

                }

                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                        .accessibilityLabel("Notes")
                        .accessibilityIdentifier("progressNotes")
                }

                if photos.isEmpty && !hasWeightText
                    && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text(hidesWeight ? "Add a photo or note to save your progress." : "Add a photo, weight, or note to save your progress.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(entry == nil ? "Add Progress" : "Edit Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        importTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("progressSave")
                }
            }
            .onAppear(perform: loadWeightOnce)
            .onChange(of: selectedPhotos) { _, selection in
                if !selection.isEmpty { importPhotos(selection) }
            }
            .onDisappear { importTask?.cancel() }
            .alert("Couldn't Save Progress", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private var photoSection: some View {
        Section {
            if !photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            VStack(spacing: 6) {
                                if let image = UIImage(data: photo.imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 112, height: 140)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .accessibilityLabel("Progress photo \(index + 1)")
                                }
                                Button("Remove", role: .destructive) {
                                    photos.removeAll { $0.id == photo.id }
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove progress photo \(index + 1)")
                            }
                        }
                    }
                }
            }

            PhotosPicker(selection: $selectedPhotos,
                         maxSelectionCount: max(1, 6 - photos.count),
                         selectionBehavior: .ordered,
                         matching: .images) {
                Label(photos.isEmpty ? "Add Photos" : "Add More Photos", systemImage: "photo.on.rectangle.angled")
            }
            .disabled(isImportingPhotos || photos.count >= 6)
            .accessibilityIdentifier("progressPhotoPicker")

            if isImportingPhotos {
                SwiftUI.ProgressView("Preparing photos…")
            }
            if let photoError {
                Text(photoError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                Button("Dismiss Photo Message") { self.photoError = nil }
                    .font(.footnote)
            }
        } header: {
            Text("Photos (\(photos.count)/6)")
        } footer: {
            Text("Choose up to six photos. Photos are saved with this check-in when you tap Save.")
        }
    }

    private func loadWeightOnce() {
        guard !didLoadWeight else { return }
        selectedUnit = WeightUnit(rawValue: weightUnitRawValue) ?? .pounds
        if !hidesWeight, let pounds = entry?.weightEntry?.weightInPounds {
            weightText = NutritionInput.format(unit.fromPounds(pounds), locale: locale)
        }
        didLoadWeight = true
    }

    private func changeUnit(to newUnit: WeightUnit) {
        // Convert the entered number so changing units preserves the weight.
        if let pounds = weightInPounds {
            weightText = NutritionInput.format(newUnit.fromPounds(pounds), locale: locale)
        }
        selectedUnit = newUnit
    }

    private func importPhotos(_ selection: [PhotosPickerItem]) {
        importTask?.cancel()
        photoError = nil
        isImportingPhotos = true
        let availableSlots = max(0, 6 - photos.count)

        // Import one photo at a time to preserve picker order and avoid
        // holding several full-resolution photo decodes in memory at once.
        importTask = Task { @MainActor in
            var failedCount = 0
            for item in selection.prefix(availableSlots) {
                do {
                    try Task.checkCancellation()
                    guard let original = try await item.loadTransferable(type: Data.self) else {
                        failedCount += 1
                        continue
                    }
                    let prepared = try await ProgressPhotoImporter.importPhoto(data: original)
                    try Task.checkCancellation()
                    if photos.count < 6 {
                        photos.append(ProgressPhotoDraft(imageData: prepared))
                    }
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    failedCount += 1
                }
            }
            guard !Task.isCancelled else { return }
            if failedCount > 0 {
                photoError = failedCount == 1
                    ? "One selected photo couldn't be added. Try choosing it again; photos stored in iCloud may need an internet connection."
                    : "\(failedCount) selected photos couldn't be added. Try choosing them again; photos stored in iCloud may need an internet connection."
            }
            selectedPhotos = []
            isImportingPhotos = false
            importTask = nil
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            _ = try ProgressEntryEditor.save(
                entry: entry, date: selectedDate, weightInPounds: weightInPounds,
                notes: notes, photos: photos, in: modelContext
            )
            weightUnitRawValue = unit.rawValue
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
