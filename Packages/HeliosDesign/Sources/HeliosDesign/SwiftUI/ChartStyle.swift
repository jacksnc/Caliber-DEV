#if canImport(SwiftUI) && canImport(Charts)
import Charts
import SwiftUI

private struct HeliosChartStyle: ViewModifier {
    @Environment(\.heliosTheme) private var theme

    func body(content: Content) -> some View {
        let palette = theme.palette
        content
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(palette.border.hairline.color)
                    AxisValueLabel().foregroundStyle(palette.text.secondary.color)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(palette.border.hairline.color)
                    AxisValueLabel().foregroundStyle(palette.text.secondary.color)
                }
            }
    }
}

extension View {
    /// Quiet hairline gridlines and secondary-text axis labels for a Swift Charts chart. Series colours come from
    /// `HeliosPalette.data`, so a macro keeps its colour in every chart.
    public func heliosChartStyle() -> some View {
        modifier(HeliosChartStyle())
    }
}

extension DataColors {
    /// Colours for a categorical `chartForegroundStyleScale`, in the order the names are given.
    public func chartRange(for names: [String]) -> [Color] {
        names.compactMap { color(named: $0)?.color }
    }
}
#endif
