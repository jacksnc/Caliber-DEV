import CaliberCore
import Charts
import HeliosDesign
import SwiftUI

/// The one filter row above the Progress charts (look book: 7D · 30D · 90D · All).
enum ProgressRange: String, CaseIterable, Identifiable {
  case week = "7D"
  case month = "30D"
  case quarter = "90D"
  case all = "All"

  var id: String { rawValue }

  var days: Int? {
    switch self {
    case .week: 7
    case .month: 30
    case .quarter: 90
    case .all: nil
    }
  }

  var spokenName: String {
    switch self {
    case .week: "7 days"
    case .month: "30 days"
    case .quarter: "90 days"
    case .all: "All time"
    }
  }

  func contains(_ date: Date, now: Date = .now) -> Bool {
    guard let days, let start = Calendar.current.date(byAdding: .day, value: -days, to: now)
    else { return true }
    return date >= start
  }
}

struct ProgressRangePicker: View {
  @Binding var selection: ProgressRange
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    // Two columns keep "30D" together at accessibility sizes, without shrinking text.
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: 2), count: typeSize.isAccessibilitySize ? 2 : 4)
    LazyVGrid(columns: columns, spacing: 2) {
      ForEach(ProgressRange.allCases) { range in
        let isSelected = range == selection
        Button {
          selection = range
        } label: {
          Text(range.rawValue)
            .heliosFont(.callout)
            .foregroundStyle(
              isSelected ? theme.palette.accent.base.color : theme.palette.text.secondary.color
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
              if isSelected { HeliosSegmentHighlight(cornerRadius: 12) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(range.spokenName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("progressRange-" + range.rawValue)
      }
    }
    .padding(4)
    .background { HeliosSegmentTrack(cornerRadius: 16) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Weight trend range")
  }
}

/// "Calories": the last seven days as bars with the daily goal as a reference line.
struct CaloriesWeekCard: View {
  let entries: [DiaryEntry]
  let goal: Double?
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale

  @ScaledMetric(relativeTo: .footnote) private var chartHeight = 104.0

  private struct Day: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
  }

  var body: some View {
    let unit = runtime.settings.energyUnit
    let days = lastSevenDays(unit: unit)
    // An unset goal is stored as 0; it draws no reference line.
    let target = goal.flatMap { $0 > 0 ? UnitFormatting.energy($0, unit: unit) : nil }
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 8) {
          Text("Calories").heliosFont(.section).accessibilityAddTraits(.isHeader)
          Spacer(minLength: 8)
          calorieDetail(target: target, unit: unit)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text("Calories").heliosFont(.section).accessibilityAddTraits(.isHeader)
          calorieDetail(target: target, unit: unit)
        }
      }
      Chart {
        ForEach(days) { day in
          BarMark(
            x: .value("Day", day.date, unit: .day), y: .value(unit.rawValue, day.value),
            width: .fixed(20)
          )
          .foregroundStyle(theme.palette.data.energy.color)
          .cornerRadius(4)
        }
        if let target {
          RuleMark(y: .value("Goal", target))
            .foregroundStyle(theme.palette.data.reference.color)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
      }
      .chartXAxis {
        AxisMarks(values: .stride(by: .day)) {
          AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
        }
      }
      .heliosChartStyle()
      .frame(height: chartHeight)
      .accessibilityElement()
      .accessibilityLabel("Calories for the last seven days")
      .accessibilityValue(summary(days, unit: unit))
      // Empty bars and a logged zero look alike, so say plainly when nothing was logged.
      if days.allSatisfy({ $0.value == 0 }) {
        Text("No food logged in the last 7 days.")
          .heliosFont(.callout)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityIdentifier("progressCalories")
  }

  private func calorieDetail(target: Double?, unit: EnergyUnit) -> some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text("Last 7 days · today so far").heliosFont(.footnote)
        .fixedSize(horizontal: false, vertical: true)
      if let target {
        Text(
          "Target \(UnitFormatting.number(target, locale: locale, fractionDigits: 0)) \(unit.rawValue)"
        )
        .heliosFont(.caption)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .foregroundStyle(theme.palette.text.secondary.color)
  }

  private func lastSevenDays(unit: EnergyUnit) -> [Day] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    return (0..<7).reversed().compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
      let total = MacroCalculator.totals(
        for: entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
      ).calories
      return Day(date: day, value: UnitFormatting.energy(total, unit: unit))
    }
  }

  private func summary(_ days: [Day], unit: EnergyUnit) -> String {
    days.map {
      "\($0.date.formatted(.dateTime.weekday(.wide))) \(UnitFormatting.number($0.value, locale: locale, fractionDigits: 0)) \(unit.rawValue)"
    }
    .joined(separator: ", ")
  }
}

/// "Macro split": the share of calories from protein, carbs and fat over seven days, as one
/// stacked bar with labelled segments.
struct MacroSplitCard: View {
  let entries: [DiaryEntry]
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale

  var body: some View {
    let since =
      Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now))
      ?? .now
    let totals = MacroCalculator.totals(for: entries.filter { $0.date >= since })
    let parts = [
      ("Protein", totals.protein, totals.protein * 4, theme.palette.data.protein.color),
      ("Carbs", totals.carbs, totals.carbs * 4, theme.palette.data.carbs.color),
      ("Fat", totals.fat, totals.fat * 9, theme.palette.data.fat.color),
    ]
    let energy = parts.reduce(0) { $0 + $1.2 }
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("Macro split").heliosFont(.section).accessibilityAddTraits(.isHeader)
          Spacer(minLength: 8)
          splitDetail
        }
        VStack(alignment: .leading, spacing: 4) {
          Text("Macro split").heliosFont(.section).accessibilityAddTraits(.isHeader)
          splitDetail
        }
      }
      if energy > 0 {
        GeometryReader { proxy in
          HStack(spacing: 2) {
            ForEach(parts.indices, id: \.self) { index in
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(parts[index].3)
                .frame(width: max(0, (proxy.size.width - 4) * parts[index].2 / energy))
            }
          }
        }
        .frame(height: 22)
        .accessibilityHidden(true)
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top) { legend(parts, energy: energy) }
          VStack(alignment: .leading) { legend(parts, energy: energy) }
        }
      } else {
        Text("Log food to see where your calories come from.")
          .heliosFont(.callout)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("progressMacroSplit")
  }

  private var splitDetail: some View {
    Text("Share of calories, 7-day average")
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private func legend(_ parts: [(String, Double, Double, Color)], energy: Double) -> some View {
    ForEach(parts.indices, id: \.self) { index in
      let part = parts[index]
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: HeliosTokens.space(1)) {
          Circle().fill(part.3).frame(width: 8, height: 8).accessibilityHidden(true)
          Text(LocalizedStringKey(part.0)).heliosFont(.metricLabel)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        HStack(alignment: .firstTextBaseline, spacing: HeliosTokens.space(1)) {
          Text("\(Int((part.2 / energy * 100).rounded()))%").heliosFont(.bodyStrong)
          Text("\(UnitFormatting.number(part.1 / 7, locale: locale, fractionDigits: 0)) g")
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
