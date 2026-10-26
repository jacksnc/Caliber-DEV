import Charts
import HeliosDesign
import SwiftUI

/// Uses the same saved weigh-ins as the timeline, so edits update the graph too.
struct WeightTrendChart: View {
  @Environment(\.heliosTheme) private var theme
  @ScaledMetric(relativeTo: .body) private var chartHeight = 210.0
  let summary: WeightProgressSummary
  let unit: WeightUnit
  let addWeight: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Weight trend", systemImage: "chart.xyaxis.line")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      if summary.readings.isEmpty {
        emptyState
      } else {
        weightSummary
        chart

        if summary.readings.count == 1 {
          Text("Your first weigh-in is on the graph. Add another to start seeing a trend.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("Each dot is a recorded weigh-in. Dates run from oldest to newest.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 8)
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("See your weight over time")
        .font(.title3.weight(.semibold))
      Text(
        "Add a weight to any daily check-in to start your graph. Photos and notes are always optional."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      Button("Log Weight", action: addWeight)
        .buttonStyle(.bordered)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
  }

  private var weightSummary: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let latest = summary.latestWeightInPounds {
        Text(
          "\(unit.fromPounds(latest), format: .number.precision(.fractionLength(0...2))) \(unit.symbol)"
        )
        .font(.title.bold())
        .accessibilityIdentifier("latestProgressWeight")
      }
      if let date = summary.readings.last?.date {
        Text("Last weigh-in: \(date.formatted(date: .abbreviated, time: .omitted))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let change = summary.changeInPounds {
        Text(
          "\(unit.fromPounds(change), format: .number.precision(.fractionLength(0...2)).sign(strategy: .always())) \(unit.symbol) since first weigh-in"
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
    }
  }

  private var chart: some View {
    Chart(summary.readings) { reading in
      // Straight segments connect actual readings without inventing peaks
      // between them; days without a weight never become zero-weight dots.
      LineMark(
        x: .value("Date", reading.date),
        y: .value("Weight (\(unit.symbol))", unit.fromPounds(reading.weightInPounds))
      )
      .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
      .foregroundStyle(theme.palette.data.weight.color)

      PointMark(
        x: .value("Date", reading.date),
        y: .value("Weight (\(unit.symbol))", unit.fromPounds(reading.weightInPounds))
      )
      .symbolSize(64)
      .foregroundStyle(theme.palette.data.weight.color)
    }
    .chartYScale(domain: .automatic(includesZero: false))
    .chartYAxisLabel(unit.symbol)
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
    .chartPlotStyle { plot in
      plot.background(Color.accentColor.opacity(0.04))
    }
    .frame(height: chartHeight)
    .accessibilityLabel("Weight history in \(unit.symbol)")
  }
}
