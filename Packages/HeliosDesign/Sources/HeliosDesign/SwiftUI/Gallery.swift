#if canImport(SwiftUI)
import SwiftUI

/// A design-review screen: type scale, colours with their audited contrast, and every component, under whichever
/// appearance the device (or the pickers below) selects. Put it behind a developer toggle and check it on a device
/// with Reduce Transparency, Increase Contrast and the largest text size switched on.
public struct HeliosGallery: View {
    @State private var preference: ThemePreference = .system
    @State private var forceReducedTransparency = false

    public init() {}

    public var body: some View {
        GalleryContent(preference: $preference, forceReducedTransparency: $forceReducedTransparency)
            .heliosThemed()
            .preferredColorScheme(preference.colorScheme)
    }

    private struct GalleryContent: View {
        @Binding var preference: ThemePreference
        @Binding var forceReducedTransparency: Bool
        @Environment(\.heliosTheme) private var theme
        @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 180

        var body: some View {
            let palette = theme.palette
            let effective = HeliosTheme(palette: palette, reduceTransparency: theme.reduceTransparency || forceReducedTransparency)
            ZStack {
                HeliosBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: HeliosTokens.space(5)) {
                        controls
                        typeScale
                        metrics
                        buttons
                        swatches
                    }
                    .padding(HeliosTokens.space(4))
                }
            }
            .environment(\.heliosTheme, effective)
        }

        private var controls: some View {
            VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
                SectionHeader("Appearance")
                Picker("Appearance", selection: $preference) {
                    ForEach(ThemePreference.allCases) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Preview Reduce Transparency", isOn: $forceReducedTransparency)
                    .heliosFont(.body)
                    .foregroundStyle(theme.palette.text.primary.color)
            }
            .glassCard()
        }

        private var typeScale: some View {
            VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
                SectionHeader("Type")
                ForEach(HeliosTypeRole.allCases, id: \.self) { role in
                    Text("\(role.rawValue) 1,234.5")
                        .heliosFont(role)
                        .foregroundStyle(theme.palette.text.primary.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }

        private var metrics: some View {
            VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
                SectionHeader("Today")
                ProgressRing(progress: 0.72, tint: theme.palette.data.energy.color) {
                    VStack {
                        Text("1,540").heliosFont(.display).foregroundStyle(theme.palette.text.primary.color)
                        Text("kcal left").heliosFont(.caption).foregroundStyle(theme.palette.text.secondary.color)
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .frame(maxWidth: .infinity)
                MetricTile("Protein", value: "132", unit: "g", accent: theme.palette.data.protein.color)
                MetricTile("Carbs", value: "184", unit: "g", accent: theme.palette.data.carbs.color)
                MetricTile("Fat", value: "58", unit: "g", accent: theme.palette.data.fat.color)
            }
            .glassCard()
        }

        private var buttons: some View {
            VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
                SectionHeader("Controls")
                Button("Log meal") {}.buttonStyle(.heliosPrimary)
                Button("Scan barcode") {}.buttonStyle(.heliosSecondary)
                HStack {
                    HeliosChip("High protein", isSelected: true)
                    HeliosChip("Vegetarian")
                }
                StatusBadge(.success, "On track")
                StatusBadge(.warning, "Check these numbers")
                StatusBadge(.danger, "Over your limit")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }

        private var swatches: some View {
            VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
                SectionHeader("Colour")
                ForEach(DataColors.names, id: \.self) { name in
                    if let color = theme.palette.data.color(named: name) {
                        HStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.color).frame(width: 28, height: 28)
                                .accessibilityHidden(true)
                            Text(name).heliosFont(.body).foregroundStyle(theme.palette.text.primary.color)
                            Spacer()
                            Text(color.hex).heliosFont(.footnote).foregroundStyle(theme.palette.text.secondary.color)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}
#endif
