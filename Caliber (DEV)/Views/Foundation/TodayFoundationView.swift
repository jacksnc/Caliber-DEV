import CaliberCore
import SwiftData
import SwiftUI

struct TodayFoundationView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query(sort: \DiaryEntry.date) private var diary: [DiaryEntry]
  @Query(sort: \ProgressEntry.date, order: .reverse) private var progress: [ProgressEntry]
  @State private var food = false
  @State private var checkIn = false
  private var today: [DiaryEntry] { diary.filter { Calendar.current.isDateInToday($0.date) } }
  var body: some View {
    NavigationStack {
      List {
        Section {
          Text(Date.now, format: .dateTime.weekday(.wide).month().day()).font(.headline)
          if today.isEmpty {
            Text("No food logged today").foregroundStyle(.secondary)
          } else {
            let totals = MacroCalculator.totals(for: today)
            LabeledContent(
              "Energy",
              value: UnitFormatting.number(
                UnitFormatting.energy(totals.calories, unit: runtime.settings.energyUnit),
                locale: Locale(identifier: runtime.settings.localeIdentifier)) + " "
                + runtime.settings.energyUnit.rawValue)
            LabeledContent(
              "Protein",
              value: UnitFormatting.number(
                totals.protein, locale: Locale(identifier: runtime.settings.localeIdentifier))
                + " g")
          }
        }
        Section("Quick Log") {
          Button {
            food = true
          } label: {
            Label("Food", systemImage: "plus.circle.fill").frame(minHeight: 48)
          }.accessibilityIdentifier("quickLogFood")
          Button {
            checkIn = true
          } label: {
            Label("Progress Check-In", systemImage: "camera").frame(minHeight: 48)
          }
        }
        Section("Explore") {
          Button {
            Task { await runtime.showDemo() }
          } label: {
            Label(
              runtime.isLoadingDemo ? "Preparing Demo…" : "Explore a Year of Demo Data",
              systemImage: "chart.xyaxis.line"
            ).frame(minHeight: 48)
          }.disabled(runtime.isLoadingDemo).accessibilityIdentifier("openDemo")
          Text("Fictional data lives in separate storage. Your diary and photos stay as they are.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }.navigationTitle("Today")
        .sheet(isPresented: $food) { FoodSearchView() }
        .sheet(isPresented: $checkIn) {
          ProgressEntryForm(entry: progress.first { Calendar.current.isDateInToday($0.date) })
        }
    }
  }
}

/// Number hiding also removes numeric views from the accessibility tree and navigation.
/// Notes/photos remain available; old numeric editors cannot leak values through a sheet.
struct NumberFreeHomeView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query(sort: \ProgressEntry.date, order: .reverse) private var entries: [ProgressEntry]
  @State private var checkIn = false
  var body: some View {
    NavigationStack {
      List {
        Section {
          Label("Numbers are hidden", systemImage: "eye.slash")
          Text("Keep a photo or note without showing calories or weight.")
          Button {
            checkIn = true
          } label: {
            Text("Add a Photo or Note").frame(minHeight: 48)
          }
        }
        ForEach(entries) { entry in
          VStack(alignment: .leading) {
            Text(entry.date, format: .dateTime.month().day().year()).font(.headline)
            if !entry.notes.isEmpty { Text(entry.notes) }
            if let data = entry.sortedPhotos.first?.imageData, let image = UIImage(data: data) {
              Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                .accessibilityLabel("Progress photo")
            }
          }
        }
        NavigationLink {
          FoundationSettingsView()
        } label: {
          Text("Settings").frame(minHeight: 48)
        }
      }.navigationTitle("Your Journal")
        .sheet(isPresented: $checkIn) {
          ProgressEntryForm(
            entry: entries.first { Calendar.current.isDateInToday($0.date) }, hidesWeight: true)
        }
    }
  }
}
