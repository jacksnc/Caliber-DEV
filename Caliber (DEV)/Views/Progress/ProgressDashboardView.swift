import HeliosDesign
import SwiftData
import SwiftUI

/// Daily check-ins stay on this device, alongside the user's food diary.
struct ProgressDashboardView: View {
  @Environment(\.modelContext) private var modelContext
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
    return WeightProgressSummary(entries: inRange.isEmpty ? weights : inRange)
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

  var body: some View {
    NavigationStack {
      List {
        Group {
          ProgressRangePicker(selection: $range)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
          Section {
            WeightTrendChart(
              summary: summary, unit: unit,
              rangeName: range == .all ? "since first weigh-in" : "in \(range.spokenName)",
              addWeight: addToday)
          }
          Section {
            CaloriesWeekCard(entries: diary, goal: profiles.first?.dailyCalorieGoal)
          }
          Section {
            MacroSplitCard(entries: diary)
          }

          if entries.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              Label("Your Progress", systemImage: "photo.on.rectangle.angled")
                .font(.title2.bold())
              Text(
                "Keep daily photos, weigh-ins, and notes together. Add any combination that works for you."
              )
              .font(.body).fixedSize(horizontal: false, vertical: true)
              Button("Add Check-In", action: addToday)
                .buttonStyle(.heliosPrimary)
            }.padding(.vertical, 8)
          } else {
            Section {
              ForEach(timelineMonths, id: \.month) { group in
                Text(group.month, format: .dateTime.month(.wide).year())
                  .font(.headline)
                  .foregroundStyle(.secondary)
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
            } header: {
              Text("Timeline · \(entries.count) \(entries.count == 1 ? "check-in" : "check-ins")")
            }

          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Progress")
      .profileAvatar()
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: addToday) {
            Label("Add Check-In", systemImage: "plus")
          }
          .accessibilityIdentifier("addProgressEntry")
        }
      }
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
