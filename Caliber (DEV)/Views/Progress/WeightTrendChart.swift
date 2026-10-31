import Charts
import HeliosDesign
import SwiftUI

/// Uses the same saved weigh-ins as the timeline, so edits update the graph too.
struct WeightTrendChart: View {
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var chartHeight = 160.0
  @State private var showsMethod = false
  @State private var showsReadings = false
  let summary: WeightProgressSummary
  let unit: WeightUnit
  var rangeName = "since first weigh-in"
  let addWeight: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if summary.readings.isEmpty {
        emptyState
      } else {
        weightSummary
        chart
        legend
        readingsTable
      }
    }
    .sheet(isPresented: $showsMethod) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text(
              "Each dot is a recorded weigh-in; the line is the smoothed trend. Dates run from oldest to newest."
            )
            Text(
              "The trend uses your saved history with a smoothing factor of 0.1. Missing days do not become zero-weight readings."
            )
            if let date = summary.readings.last?.date {
              Text("Last weigh-in: \(date.formatted(date: .abbreviated, time: .omitted))")
            }
          }
          .padding()
        }
        .caliberScreen()
        .navigationTitle("Weight trend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { showsMethod = false } }
      }
    }
  }

  private var emptyState: some View {
    HeliosEmptyState(
      symbol: "scalemass",
      title: "See your weight over time",
      message:
        "Add a weight to any daily check-in to start your graph. Photos and notes are always optional."
    ) {
      Button("Log Weight", action: addWeight)
        .buttonStyle(.heliosSecondary)
    }
  }

  /// Look book: "Trend weight" with the latest value large, and the change over the
  /// selected range on the right.
  @ViewBuilder private var weightSummary: some View {
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
        latest
        HStack(alignment: .top) {
          change
          Spacer()
          methodButton
        }
      }
    } else {
      HStack(alignment: .top) {
        latest
        Spacer(minLength: HeliosTokens.space(3))
        HStack(alignment: .top, spacing: 2) {
          change.multilineTextAlignment(.trailing)
          methodButton
        }
      }
    }
  }

  private var methodButton: some View {
    Button {
      showsMethod = true
    } label: {
      Image(systemName: "info.circle").font(.footnote)
        .foregroundStyle(theme.palette.text.secondary.color)
        .frame(width: 44, height: 44)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("How the weight trend is calculated")
    .accessibilityIdentifier("weightTrendMethod")
  }

  private var latest: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Trend weight").heliosFont(.metricLabel)
        .foregroundStyle(theme.palette.text.secondary.color)
      if let latest = summary.latestTrendInPounds ?? summary.latestWeightInPounds {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(unit.fromPounds(latest), format: .number.precision(.fractionLength(0...2)))
            .heliosFont(.hero)
            .fixedSize(horizontal: false, vertical: true)
          Text(unit.symbol).heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("latestProgressWeight")
      }
    }
  }

  @ViewBuilder private var change: some View {
    if let change = summary.trendChangeInPounds ?? summary.changeInPounds {
      VStack(alignment: .trailing, spacing: 2) {
        Text(
          "\(unit.fromPounds(change), format: .number.precision(.fractionLength(0...2)).sign(strategy: .always())) \(unit.symbol)"
        )
        .heliosFont(.bodyStrong)
        .fixedSize(horizontal: false, vertical: true)
        Text(rangeName).heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
    }
  }

  /// Names both marks next to the chart; the method sheet explains them in full.
  private var legend: some View {
    let color = theme.palette.data.weight.color
    return ViewThatFits(in: .horizontal) {
      HStack(spacing: HeliosTokens.space(4)) { legendItems(color) }
        .fixedSize(horizontal: true, vertical: false)
      VStack(alignment: .leading, spacing: HeliosTokens.space(1)) { legendItems(color) }
    }
    .heliosFont(.caption)
    .foregroundStyle(theme.palette.text.secondary.color)
    .accessibilityHidden(true)
  }

  @ViewBuilder private func legendItems(_ color: Color) -> some View {
    HStack(spacing: HeliosTokens.space(1)) {
      Circle().fill(color.opacity(0.5)).frame(width: 8, height: 8)
      Text("Weigh-in").fixedSize(horizontal: false, vertical: true)
    }
    HStack(spacing: HeliosTokens.space(1)) {
      Capsule().fill(color).frame(width: 16, height: 2)
      Text("Smoothed trend").fixedSize(horizontal: false, vertical: true)
    }
  }

  /// The chart's text alternative: every recorded weigh-in in the range, newest first.
  /// A plain button, not a DisclosureGroup, so a tap on this list row opens nothing else.
  private var readingsTable: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
      Button {
        showsReadings.toggle()
      } label: {
        HStack(spacing: HeliosTokens.space(1)) {
          Text(showsReadings ? "Hide weigh-ins" : "Show weigh-ins")
            .fixedSize(horizontal: false, vertical: true)
          Image(systemName: showsReadings ? "chevron.up" : "chevron.down")
            .accessibilityHidden(true)
        }
        .heliosFont(.callout)
        .foregroundStyle(theme.palette.accent.base.color)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityValue(showsReadings ? "Shown" : "Hidden")
      .accessibilityIdentifier("weightTrendReadings")
      if showsReadings {
        ForEach(Array(summary.readings.reversed())) { reading in readingRow(reading) }
      }
    }
  }

  private func readingRow(_ reading: WeightEntry) -> some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: HeliosTokens.space(3)))
    return layout {
      Text(
        reading.date,
        format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year()
      )
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      Text(
        "\(unit.fromPounds(reading.weightInPounds), format: .number.precision(.fractionLength(0...2))) \(unit.symbol)"
      )
      .heliosFont(.bodyStrong)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(minHeight: 36)
    .accessibilityElement(children: .combine)
  }

  private var chart: some View {
    let color = theme.palette.data.weight.color
    return Chart {
      // Each dot is one real weigh-in; days without one stay empty, never zero.
      ForEach(summary.readings) { reading in
        PointMark(
          x: .value("Date", reading.date),
          y: .value("Weight (\(unit.symbol))", unit.fromPounds(reading.weightInPounds))
        )
        .symbolSize(22)
        .foregroundStyle(color.opacity(0.5))
      }
      // The smoothed trend (brief §9.3) joins only days that have a weigh-in.
      ForEach(summary.trend) { point in
        LineMark(
          x: .value("Date", point.date),
          y: .value("Trend (\(unit.symbol))", unit.fromPounds(point.pounds)),
          series: .value("Series", "Trend")
        )
        .interpolationMethod(.monotone)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .foregroundStyle(color)
      }
      if let last = summary.trend.last {
        PointMark(
          x: .value("Date", last.date),
          y: .value("Trend (\(unit.symbol))", unit.fromPounds(last.pounds))
        )
        .symbolSize(90)
        .foregroundStyle(color)
      }
    }
    .chartYScale(domain: .automatic(includesZero: false))
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
        AxisValueLabel()
      }
    }
    .chartXAxis {
      if summary.readings.count == 1, let reading = summary.readings.first {
        // One recorded day needs one label, not repeated sub-day ticks.
        AxisMarks(values: [reading.date]) {
          AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
      } else {
        // Automatic labels adapt as the history grows into months/years.
        AxisMarks(values: .automatic(desiredCount: 4)) {
          AxisValueLabel()
        }
      }
    }
    .frame(height: chartHeight)
    .accessibilityLabel("Weight history in \(unit.symbol)")
    .accessibilityHint("Each dot is a recorded weigh-in; the line is the smoothed trend.")
  }
}
