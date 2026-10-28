import HeliosDesign
import SwiftData
import SwiftUI

/// Daily check-ins stay on this device, alongside the user's food diary.
struct ProgressDashboardView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.heliosTheme) private var theme
  @Query(sort: \ProgressEntry.date, order: .reverse) private var entries: [ProgressEntry]
  @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
  @Query(sort: \DiaryEntry.date) private var diary: [DiaryEntry]
  @Query private var profiles: [UserProfile]
  @State private var range = ProgressRange.month
  @AppStorage("progressWeightUnit") private var unitRawValue = WeightUnit.pounds.rawValue
  @State private var isAddingEntry = false
  @State private var editingEntry: ProgressEntry?
  @State private var deletingEntry: ProgressEntry?
  @State private var saveError: String?

  private var unit: WeightUnit { WeightUnit(rawValue: unitRawValue) ?? .pounds }
  /// Weigh-ins in the selected range; older history is still shown when the range is empty.
  private var summary: WeightProgressSummary {
    let inRange = weights.filter { range.contains($0.date) }
    return WeightProgressSummary(entries: inRange.isEmpty ? weights : inRange, history: weights)
  }
  private var todayEntry: ProgressEntry? {
    entries.first { Calendar.current.isDateInToday($0.date) }
  }

  // Group the existing history for display; check-ins keep their original dates.
  private var timelineMonths: [(month: Date, entries: [ProgressEntry])] {
    let calendar = Calendar.current
    let groups = Dictionary(grouping: entries) {
      calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
    }
    return groups.map { (month: $0.key, entries: $0.value) }
      .sorted { $0.month > $1.month }
  }

  private var timelineDetail: String {
    guard !entries.isEmpty else { return "No check-ins yet" }
    let count = entries.count == 1 ? "1 check-in" : "\(entries.count) check-ins"
    return "\(count) · newest first · swipe to edit or delete"
  }

  var body: some View {
    NavigationStack {
      List {
        Group {
          // The range row scopes only the weight trend directly below it.
          Section {
            ProgressRangePicker(selection: $range)
              .padding(.bottom, HeliosTokens.space(2))
              .listRowBackground(Color.clear)
              .listRowSeparator(.hidden)
              .listRowInsets(EdgeInsets())
            WeightTrendChart(
              summary: summary, unit: unit,
              rangeName: range == .all ? "since first weigh-in" : "in \(range.spokenName)",
              addWeight: addToday
            )
            .caliberCardRow()
          } header: {
            CaliberHeader(
              "Progress", identifier: "Progress", action: addToday,
              actionLabel: "Add Check-In", actionIdentifier: "addProgressEntry"
            )
            .caliberSectionHeader()
          }

          // Food cards are always the last seven days, whatever weight range is selected.
          Section {
            CaloriesWeekCard(entries: diary, goal: profiles.first?.dailyCalorieGoal)
              .caliberCardRow()
          } header: {
            ProgressSectionHeader(
              "Nutrition", detail: "Last 7 days · not affected by the range above",
              identifier: "progressNutritionHeader")
          }
          Section {
            MacroSplitCard(entries: diary)
              .caliberCardRow()
          }

          Section {
            if entries.isEmpty {
              HeliosEmptyState(
                symbol: "photo.on.rectangle.angled",
                title: "Your Progress",
                message:
                  "Keep daily photos, weigh-ins, and notes together. Add any combination that works for you."
              ) {
                Button("Add Check-In", action: addToday)
                  .buttonStyle(.heliosPrimary)
                  .accessibilityIdentifier("progressEmptyAddCheckIn")
              }
              .caliberCardRow()
            } else {
              ForEach(timelineMonths, id: \.month) { group in
                Text(group.month, format: .dateTime.month(.wide).year())
                  .heliosFont(.section)
                  .foregroundStyle(theme.palette.text.secondary.color)
                  .listRowBackground(Color.clear)
                  .listRowSeparator(.hidden)
                  .listRowInsets(EdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 16))
                  .accessibilityAddTraits(.isHeader)

                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                  NavigationLink {
                    ProgressEntryDetailView(entry: entry)
                  } label: {
                    ProgressTimelineRow(
                      entry: entry, unit: unit,
                      isFirst: index == 0,
                      isLast: index == group.entries.count - 1
                    )
                  }
                  .listRowBackground(Color.clear)
                  .listRowSeparator(.hidden)
                  .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                  .accessibilityIdentifier("progressEntry-\(entry.id)")
                  .accessibilityHint("Open check-in. Actions available to edit or delete.")
                  .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                      deletingEntry = entry
                    } label: {
                      Label("Delete", systemImage: "trash")
                    }
                    Button {
                      editingEntry = entry
                    } label: {
                      Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                  }
                }
              }
            }
          } header: {
            ProgressSectionHeader(
              "Timeline", detail: timelineDetail, identifier: "progressTimelineHeader")
          }
        }
      }
      .contentMargins(.top, 0, for: .scrollContent)
      .listSectionSpacing(12)
      .caliberScreen()
      .compactNavigationTitle("Progress")
      .profileAvatar()
      .sheet(isPresented: $isAddingEntry) { ProgressEntryForm() }
      .sheet(item: $editingEntry) { ProgressEntryForm(entry: $0) }
      .alert(
        "Delete Check-In?",
        isPresented: Binding(
          get: { deletingEntry != nil },
          set: { if !$0 { deletingEntry = nil } }
        ), presenting: deletingEntry
      ) { entry in
        Button("Delete", role: .destructive) { delete(entry) }
        Button("Cancel", role: .cancel) { deletingEntry = nil }
      } message: { _ in
        Text(
          "This removes this check-in's photos, weight, and notes from the app. Your photo library is unchanged."
        )
      }
      .alert(
        "Couldn't Save Change",
        isPresented: Binding(
          get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )
      ) {
        Button("OK", role: .cancel) { saveError = nil }
      } message: {
        Text(saveError ?? "Please try again.")
      }
    }
  }

  private func addToday() {
    // Adding again today edits the same check-in rather than creating a duplicate.
    if let todayEntry { editingEntry = todayEntry } else { isAddingEntry = true }
  }

  private func delete(_ entry: ProgressEntry) {
    do {
      try ProgressEntryEditor.delete(entry: entry, in: modelContext)
      deletingEntry = nil
    } catch {
      deletingEntry = nil
      saveError = error.localizedDescription
    }
  }
}

/// A section heading on the bare canvas: primary title, secondary detail (both audited on canvas).
private struct ProgressSectionHeader: View {
  let title: LocalizedStringKey
  let detail: String
  let identifier: String
  @Environment(\.heliosTheme) private var theme

  init(_ title: LocalizedStringKey, detail: String, identifier: String) {
    self.title = title
    self.detail = detail
    self.identifier = identifier
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .heliosFont(.section)
        .foregroundStyle(theme.palette.text.primary.color)
        .accessibilityAddTraits(.isHeader)
      Text(detail)
        .heliosFont(.footnote)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, HeliosTokens.space(2))
    .caliberSectionHeader()
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(identifier)
  }
}

private struct ProgressEntryDetailView: View {
  let entry: ProgressEntry
  @AppStorage("progressWeightUnit") private var unitRawValue = WeightUnit.pounds.rawValue
  @State private var isEditing = false
  private var unit: WeightUnit { WeightUnit(rawValue: unitRawValue) ?? .pounds }

  var body: some View {
    List {
      Group {
        if !entry.photos.isEmpty {
          Section("Photos") {
            // Keep the saved selection order, even after reopening the app.
            ForEach(entry.sortedPhotos) { photo in
              if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                  .resizable().scaledToFit()
                  .clipShape(RoundedRectangle(cornerRadius: 10))
                  .accessibilityLabel("Progress photo \(photo.sortOrder + 1)")
              }
            }
          }
        }
        if let weight = entry.weightEntry?.weightInPounds {
          Section("Weight") {
            Text(
              "\(unit.fromPounds(weight), format: .number.precision(.fractionLength(0...2))) \(unit.symbol)"
            )
          }
        }
        if !entry.notes.isEmpty {
          Section("Notes") {
            Text(entry.notes).textSelection(.enabled)
          }
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle(entry.date.formatted(date: .abbreviated, time: .omitted))
    .toolbar(.visible, for: .navigationBar)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      Button("Edit") { isEditing = true }
        .accessibilityIdentifier("editProgressEntry")
    }
    .sheet(isPresented: $isEditing) { ProgressEntryForm(entry: entry) }
  }
}

#Preview {
  ProgressDashboardView()
    .modelContainer(
      for: [ProgressEntry.self, WeightEntry.self, ProgressPhoto.self], inMemory: true)
}
