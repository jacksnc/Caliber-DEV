import SwiftData
import SwiftUI

struct DiaryCopyRequest: Identifiable {
  let id = UUID()
  let date: Date
  let meal: MealType?
  var sourceDate: Date? = nil
}

/// Review each food before repeating a meal or day. Save adds independent copies.
struct CopyDiaryView: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \DiaryEntry.date) private var entries: [DiaryEntry]
  let destination: Date
  @State private var sourceDate: Date
  @State private var sourceMeal: MealType?
  @State private var destinationMeal: MealType?
  @State private var excluded: Set<UUID> = []
  @State private var completedSourceIDs: Set<UUID>?
  @State private var didCopy = false
  @State private var saveError: String?

  init(request: DiaryCopyRequest, calendar: Calendar) {
    destination = request.date
    _sourceDate = State(
      initialValue: request.sourceDate ?? DiaryDay.previous(
        before: request.date, calendar: calendar) ?? request.date)
    _sourceMeal = State(initialValue: request.meal)
    _destinationMeal = State(initialValue: request.meal)
  }
  private var source: [DiaryEntry] {
    entries.filter {
      calendar.isDate($0.date, inSameDayAs: sourceDate)
        && (sourceMeal == nil || $0.mealType == sourceMeal)
        && (completedSourceIDs?.contains($0.id) ?? true)
    }
    .sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
  }
  private var selected: [DiaryEntry] { source.filter { !excluded.contains($0.id) } }
  private var totals: MacroTotals? { try? DiaryRepeatLogger.preview(entries: selected) }

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section("Copy From") {
            DatePicker("Source Day", selection: $sourceDate, displayedComponents: .date)
              .accessibilityIdentifier("copySourceDay")
            Picker("Source Meal", selection: $sourceMeal) {
              Text("Whole Day").tag(Optional<MealType>.none)
              ForEach(MealType.allCases) { Text($0.displayName).tag(Optional($0)) }
            }.accessibilityIdentifier("copySourceMeal")
          }
          Section("Add To") {
            Text(destination, format: .dateTime.weekday().month().day().year())
            Picker("Meal", selection: $destinationMeal) {
              Text("Original Meals").tag(Optional<MealType>.none)
              ForEach(MealType.allCases) { Text($0.displayName).tag(Optional($0)) }
            }.accessibilityIdentifier("copyDestinationMeal")
            if calendar.isDate(sourceDate, inSameDayAs: destination) {
              Text("You are copying within the same day.").font(.footnote)
            }
          }
          Section {
            if source.isEmpty { Text("No foods were logged for this day and meal.") }
            ForEach(source) { entry in
              Button {
                if excluded.contains(entry.id) {
                  excluded.remove(entry.id)
                } else {
                  excluded.insert(entry.id)
                }
                didCopy = false
              } label: {
                HStack(alignment: .top) {
                  Image(
                    systemName: excluded.contains(entry.id) ? "circle" : "checkmark.circle.fill")
                  VStack(alignment: .leading, spacing: 4) {
                    Text(entry.foodItem?.name ?? "Missing Food")
                    if let row = try? DiaryRepeatLogger.preview(entries: [entry]) {
                      Text(
                        "\(entry.mealType.displayName) · \(NutritionInput.format(entry.quantity, locale: locale)) portions · \(NutritionInput.format(row.calories, locale: locale)) cal"
                      ).font(.footnote)
                    } else {
                      Text("Portion or nutrition unavailable").font(.footnote)
                    }
                  }
                }.frame(minHeight: 48).foregroundStyle(.primary)
              }.buttonStyle(.plain)
                .accessibilityLabel(entry.foodItem?.name ?? "Missing Food")
                .accessibilityValue(excluded.contains(entry.id) ? "Not selected" : "Selected")
                .accessibilityIdentifier("copyFood-\(entry.id.uuidString)")
                .disabled(didCopy)
            }
          } header: {
            Text("Foods to Copy")
          } footer: {
            Text("Select the foods you want. This adds new entries and keeps your original logs.")
          }
          if let totals {
            Section("Copy Total") {
              Text(
                "\(selected.count) \(selected.count == 1 ? "food" : "foods") · \(NutritionInput.format(totals.calories, locale: locale)) calories"
              )
              .accessibilityIdentifier("copyCalories")
              Text(
                "Protein \(NutritionInput.format(totals.protein, locale: locale))g · Carbs \(NutritionInput.format(totals.carbs, locale: locale))g · Fat \(NutritionInput.format(totals.fat, locale: locale))g"
              )
            }
          } else if !selected.isEmpty {
            Text(
              "A selected food needs a valid name, portion and nutrition. Edit it in the diary or leave it out of this copy."
            )
          }
          if didCopy {
            Label("Foods copied", systemImage: "checkmark.circle").accessibilityIdentifier(
              "copySaved")
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Copy Foods")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(didCopy ? "Done" : "Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Copy Foods", action: copy).disabled(totals == nil || didCopy)
            .frame(minHeight: 48).accessibilityIdentifier("copyConfirm")
        }
      }
      .onChange(of: sourceDate) { _, _ in
        excluded = []
        completedSourceIDs = nil
        didCopy = false
      }
      .onChange(of: sourceMeal) { _, _ in
        excluded = []
        completedSourceIDs = nil
        didCopy = false
      }
      .onChange(of: destinationMeal) { _, _ in didCopy = false }
      .alert(
        "Couldn't Copy Foods",
        isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
      ) {
        Button("OK", role: .cancel) { saveError = nil }
      } message: {
        Text(saveError ?? "Please try again.")
      }
    }
  }
  private func copy() {
    guard !didCopy, totals != nil else { return }
    let originalSourceIDs = Set(source.map(\.id))
    do {
      try DiaryRepeatLogger.copy(
        entries: selected, to: destination, meal: destinationMeal, in: context)
      completedSourceIDs = originalSourceIDs
      didCopy = true
    } catch {
      saveError = "Your foods could not be copied. Your original logs are still available."
    }
  }
}
