import CaliberCore
import CaliberDesignSystem
import Charts
import SwiftUI

public struct ChartCard: View {
  let title: String
  let unit: String
  let observations: [ChartObservation]
  let color: Color
  let hidesNumbers: Bool
  @State private var range: ChartPeriod = .year
  @State private var selected: Date?
  @Environment(\.locale) private var locale
  @Environment(\.calendar) private var calendar
  @Environment(\.timeZone) private var timeZone
  @Environment(\.colorScheme) private var scheme
  @Environment(\.dynamicTypeSize) private var dynamicType

  public init(
    title: String, unit: String, observations: [ChartObservation], color: Color,
    hidesNumbers: Bool = false
  ) {
    self.title = title
    self.unit = unit
    self.observations = observations
    self.color = color
    self.hidesNumbers = hidesNumbers
  }
  private var localCalendar: Calendar {
    var value = calendar
    value.timeZone = timeZone
    return value
  }
  private var window: CalendarChartWindow {
    CalendarChartWindow(observations: observations, period: range, calendar: localCalendar)
  }
  private func copy(_ key: String.LocalizationValue) -> String {
    CaliberCopy.text(key, locale: locale)
  }
  private func dateLabel(_ date: Date) -> String {
    date.formatted(
      Date.FormatStyle(
        date: .abbreviated, time: .omitted, locale: locale, calendar: localCalendar,
        timeZone: timeZone))
  }
  public var body: some View {
    let window = window
    let palette = CaliberTheme.palette(scheme: scheme)
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
          Text(copy("Unit: \(unit)")).font(.caption).foregroundStyle(palette.secondaryText)
        }
        Spacer(minLength: 8)
        NavigationLink {
          method
        } label: {
          Image(systemName: "info.circle").frame(minWidth: 48, minHeight: 48)
        }.accessibilityLabel(copy("How this chart works"))
      }
      if hidesNumbers {
        Label(copy("Numbers hidden"), systemImage: "eye.slash").foregroundStyle(
          palette.secondaryText)
      } else {
        rangePicker
        if window.valid.isEmpty {
          CaliberEmptyState(
            title: copy("No observations"),
            message: copy("Missing logs stay empty. Add an entry to begin."))
        } else {
          Text(copy("\(window.loggedDayCount) of \(window.dayCount) days logged"))
            .font(.caption).foregroundStyle(palette.secondaryText)
          chart(window)
          summary(window)
        }
        if !window.days.isEmpty {
          NavigationLink(copy("View data table")) { dataTable }
            .frame(minHeight: CaliberTheme.minimumInteractiveSize)
        }
      }
    }
    .padding(CaliberTheme.cardPadding)
    .foregroundStyle(palette.text)
    .tint(palette.accent)
    .background(palette.surface, in: RoundedRectangle(cornerRadius: CaliberTheme.cardRadius))
    .overlay(
      RoundedRectangle(cornerRadius: CaliberTheme.cardRadius).stroke(palette.border, lineWidth: 1)
    )
    .onChange(of: range) { _, _ in selected = nil }
    .onChange(of: hidesNumbers) { _, _ in selected = nil }
  }
  private var rangePicker: some View {
    Group {
      if dynamicType.isAccessibilitySize {
        periodPicker.pickerStyle(.menu)
      } else {
        periodPicker.pickerStyle(.segmented)
      }
    }.frame(minHeight: CaliberTheme.minimumInteractiveSize)
  }
  private var periodPicker: some View {
    Picker(copy("Date range"), selection: $range) {
      Text(copy("1W")).tag(ChartPeriod.week).accessibilityLabel(copy("One week"))
      Text(copy("1M")).tag(ChartPeriod.month).accessibilityLabel(copy("One month"))
      Text(copy("3M")).tag(ChartPeriod.quarter).accessibilityLabel(copy("Three months"))
      Text(copy("1Y")).tag(ChartPeriod.year).accessibilityLabel(copy("One year"))
    }
  }
  private func chart(_ window: CalendarChartWindow) -> some View {
    Chart {
      ForEach(window.marks) { mark in
        if let value = mark.observation.value {
          LineMark(
            x: .value(copy("Date"), mark.observation.date), y: .value(unit, value),
            series: .value(copy("Continuous segment"), mark.segment)
          )
          .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
          PointMark(x: .value(copy("Date"), mark.observation.date), y: .value(unit, value))
            .foregroundStyle(color).symbolSize(12)
        }
      }
      if let selected {
        RuleMark(x: .value(copy("Selected date"), selected)).foregroundStyle(.secondary)
      }
    }
    .chartXScale(domain: window.dateDomain ?? Date.distantPast...Date.distantFuture)
    .chartYScale(domain: .automatic(includesZero: false))
    .frame(height: dynamicType.isAccessibilitySize ? 220 : 180)
    .chartXSelection(value: $selected)
    // No draw animation: stable first paint and no extra motion under Reduce Motion.
    .transaction { $0.animation = nil }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(
      copy("\(window.valid.count) recorded observations. Exact values are in the data table.")
    )
    .accessibilityIdentifier("foundationChart-" + title)
  }
  @ViewBuilder private func summary(_ window: CalendarChartWindow) -> some View {
    if let selected,
      let point = window.valid.min(by: {
        abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected))
      }), let value = point.value
    {
      Text(
        copy("\(dateLabel(point.date)): \(UnitFormatting.number(value, locale: locale)) \(unit)")
      )
      .font(.caption).monospacedDigit().fixedSize(horizontal: false, vertical: true)
    } else if let first = window.valid.first?.value, let last = window.valid.last?.value {
      Text(
        copy("First-to-last change: \(UnitFormatting.number(last - first, locale: locale)) \(unit)")
      )
      .font(.subheadline).monospacedDigit().fixedSize(horizontal: false, vertical: true)
    }
  }
  private var dataTable: some View {
    List {
      if hidesNumbers {
        Label(copy("Numbers hidden"), systemImage: "eye.slash")
      } else {
        ForEach(window.days) { day in
          Section(dateLabel(day.date)) {
            if day.observations.isEmpty {
              Text(copy("Not logged")).foregroundStyle(.secondary)
            } else {
              ForEach(day.observations) { point in
                if let value = point.value, value.isFinite {
                  Text(copy("\(UnitFormatting.number(value, locale: locale)) \(unit)"))
                    .monospacedDigit()
                } else {
                  Text(copy("Not logged")).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }
    }.navigationTitle(title)
  }
  private var method: some View {
    List {
      Text(
        copy(
          "This chart shows recorded values. Empty days remain gaps; no missing value is replaced with zero."
        ))
      Text(
        copy(
          "Periods end on the latest date in the series. A month or year uses calendar dates, and coverage counts distinct days with a recorded value."
        ))
      Text(
        copy(
          "First-to-last change subtracts the first recorded value in the selected range from the last. It is descriptive, not a forecast or a claim about cause."
        ))
      Text(
        copy(
          "The data table exposes every value in the selected range. Demo values are fictional and are not recommended targets."
        ))
    }.navigationTitle(copy("How we calculate"))
  }
}

public struct DemoDashboard: View {
  let dataset: DemoDataset
  let hidesNumbers: Bool
  @State private var showSimulation = false
  @Environment(\.colorScheme) private var scheme
  @Environment(\.locale) private var locale
  public init(dataset: DemoDataset, hidesNumbers: Bool = false) {
    self.dataset = dataset
    self.hidesNumbers = hidesNumbers
  }
  private func observations(_ key: KeyPath<DemoDay, Double?>) -> [ChartObservation] {
    dataset.days.map { ChartObservation(id: $0.localDate, date: $0.date, value: $0[keyPath: key]) }
  }
  private func copy(_ key: String.LocalizationValue) -> String {
    CaliberCopy.text(key, locale: locale)
  }
  private var demoTimeZone: TimeZone { TimeZone(identifier: dataset.timeZoneID) ?? .gmt }
  private var demoCalendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = demoTimeZone
    return value
  }
  public var body: some View {
    let palette = CaliberTheme.palette(scheme: scheme)
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 20) {
        Label(copy("Fictional demo • Separate from your logs"), systemImage: "sparkles").font(
          .headline)
        Text(copy("Explore a year with a cut phase, deloads, noisy weigh-ins, and missed logs."))
          .foregroundStyle(palette.secondaryText)
        ChartCard(
          title: copy("Body weight"), unit: "kg", observations: observations(\.weightKG),
          color: palette.body, hidesNumbers: hidesNumbers)
        ChartCard(
          title: copy("Food energy"), unit: "kcal", observations: observations(\.calories),
          color: palette.fuel, hidesNumbers: hidesNumbers)
        ChartCard(
          title: copy("Protein"), unit: "g", observations: observations(\.protein),
          color: palette.fuel, hidesNumbers: hidesNumbers)
        ChartCard(
          title: copy("Training volume"), unit: "kg",
          observations: observations(\.trainingVolumeKG), color: palette.train,
          hidesNumbers: hidesNumbers)
        NavigationLink(copy("Explore the timeline")) {
          List(dataset.days.reversed()) { day in
            VStack(alignment: .leading) {
              Text(day.date, format: .dateTime.month().day().year()).font(.headline)
              Text(day.phase == "Cut" ? copy("Cut") : copy("Maintenance"))
              if day.isDeload { Label(copy("Deload"), systemImage: "arrow.down.right") }
              if day.trainingSets != nil { Label(copy("Training logged"), systemImage: "dumbbell") }
              if day.calories != nil { Label(copy("Food logged"), systemImage: "fork.knife") }
              if day.weightKG != nil { Label(copy("Weigh-in logged"), systemImage: "scalemass") }
            }.accessibilityElement(children: .combine)
          }.navigationTitle(copy("Demo timeline"))
        }.frame(minHeight: CaliberTheme.minimumInteractiveSize)
        Toggle(copy("Show fictional private-track simulation"), isOn: $showSimulation).frame(
          minHeight: CaliberTheme.minimumInteractiveSize)
        if showSimulation {
          Text(
            copy(
              "Arbitrary units only. No substance, human dose, prescription, or real reminder is represented."
            )
          ).font(.footnote)
          ChartCard(
            title: copy("Fictional simulation"), unit: "a.u.",
            observations: dataset.simulation.map {
              ChartObservation(id: $0.id, date: $0.date, value: $0.missed ? nil : $0.level)
            }, color: palette.stack, hidesNumbers: hidesNumbers)
        }
      }.padding()
    }
    .background(palette.background).foregroundStyle(palette.text)
    .navigationTitle(copy("Demo"))
    .environment(\.calendar, demoCalendar).environment(\.timeZone, demoTimeZone)
  }
}
