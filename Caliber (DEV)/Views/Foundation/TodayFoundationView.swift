import CaliberCore
import HeliosDesign
import SwiftData
import SwiftUI

struct TodayFoundationView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query(sort: \DiaryEntry.date) private var diary: [DiaryEntry]
  @Query(sort: \ProgressEntry.date, order: .reverse) private var progress: [ProgressEntry]
  @State private var food = false
  @State private var checkIn = false
  private var today: [DiaryEntry] { diary.filter { Calendar.current.isDateInToday($0.date) } }
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.locale) private var locale

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(Date.now, format: .dateTime.weekday(.wide).month().day())
            .font(.headline).foregroundStyle(theme.palette.text.secondary.color)

          VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Today's Nutrition")
            if today.isEmpty {
              Text("No food logged today").foregroundStyle(theme.palette.text.secondary.color)
            } else {
              let totals = MacroCalculator.totals(for: today)
              LazyVGrid(columns: columns, spacing: 12) {
                MetricTile(
                  "Energy",
                  value: number(
                    UnitFormatting.energy(totals.calories, unit: runtime.settings.energyUnit)),
                  unit: runtime.settings.energyUnit.rawValue,
                  accent: theme.palette.data.energy.color)
                MetricTile(
                  "Protein", value: number(totals.protein), unit: "g",
                  accent: theme.palette.data.protein.color)
                MetricTile(
                  "Carbs", value: number(totals.carbs), unit: "g",
                  accent: theme.palette.data.carbs.color)
                MetricTile(
                  "Fat", value: number(totals.fat), unit: "g", accent: theme.palette.data.fat.color)
              }
            }
          }.glassCard()

          VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Quick Log")
            Button {
              food = true
            } label: {
              Label("Food", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.heliosPrimary).accessibilityIdentifier("quickLogFood")
            Button {
              checkIn = true
            } label: {
              Label("Progress Check-In", systemImage: "camera")
                .frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.heliosSecondary)
          }.glassCard()

          VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Explore")
            Button {
              Task { await runtime.showDemo() }
            } label: {
              Label(
                runtime.isLoadingDemo ? "Preparing Demo…" : "Explore a Year of Demo Data",
                systemImage: "chart.xyaxis.line"
              )
              .frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.heliosSecondary)
              .disabled(runtime.isLoadingDemo).accessibilityIdentifier("openDemo")
            Text(
              "Fictional data lives in separate storage. Your diary and photos stay as they are."
            )
            .font(.footnote).foregroundStyle(theme.palette.text.secondary.color)
          }.glassCard()
        }.padding()
      }
      .caliberScreen()
      .navigationTitle("Today")
      .sheet(isPresented: $food) { NavigationStack { FoodSearchView() } }
      .sheet(isPresented: $checkIn) {
        ProgressEntryForm(entry: progress.first { Calendar.current.isDateInToday($0.date) })
      }
    }
  }

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2
    )
  }

  private func number(_ value: Double) -> String {
    UnitFormatting.number(value, locale: locale)
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
        Group {
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
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen().navigationTitle("Your Journal")
      .sheet(isPresented: $checkIn) {
        ProgressEntryForm(
          entry: entries.first { Calendar.current.isDateInToday($0.date) }, hidesWeight: true)
      }
    }
  }
}
