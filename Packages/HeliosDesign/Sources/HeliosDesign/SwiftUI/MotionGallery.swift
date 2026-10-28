#if canImport(SwiftUI)
import SwiftUI

/// A design-review screen for depth and motion: every new effect wired to sample data, so it can be judged on a
/// device. Check it with Reduce Motion, Reduce Transparency and Increase Contrast each switched on: the sweep, sparks,
/// rise and scroll scaling must disappear, leaving fades and the opaque fallbacks. Put it beside `HeliosGallery`
/// behind the same developer toggle.
public struct HeliosMotionGallery: View {
    @State private var preference: ThemePreference = .system

    public init() {}

    public var body: some View {
        MotionGalleryContent(preference: $preference)
            .heliosThemed()
            .preferredColorScheme(preference.colorScheme)
    }
}

private struct MotionGalleryContent: View {
    @Binding var preference: ThemePreference
    @State private var eaten: Double = 1_260
    @State private var replay = 0
    @State private var records = 0
    @State private var toast: HeliosToast?
    @Environment(\.heliosTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 180
    @ScaledMetric(relativeTo: .title) private var badgeSize: CGFloat = 72

    private let target: Double = 2_200
    private let weekly: [Double] = [0.62, 0.8, 0.71, 0.94, 0.55, 0.88, 0.76]

    var body: some View {
        ZStack {
            HeliosBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: HeliosTokens.space(5)) {
                    controls.heliosEntrance(order: 0)
                    fuel.heliosEntrance(order: 1)
                    record.heliosEntrance(order: 2)
                    week.heliosEntrance(order: 3)
                    tiles.heliosEntrance(order: 4)
                }
                .id(replay)
                .padding(HeliosTokens.space(4))
            }
        }
        .heliosToast($toast)
    }

    private var palette: HeliosPalette { theme.palette }

    private var controls: some View {
        VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
            SectionHeader("Depth and motion")
            Picker("Appearance", selection: $preference) {
                ForEach(ThemePreference.allCases) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Button("Replay entrance") { replay += 1 }
                .buttonStyle(.heliosSecondary)
        }
        .deepGlassCard()
        .heliosScrollDepth()
    }

    /// Logging food fills the ring, rolls the number, sweeps light across the card, taps and confirms.
    private var fuel: some View {
        let left = max(target - eaten, 0)
        return VStack(spacing: HeliosTokens.space(3)) {
            SectionHeader("Fuel")
            ProgressRing(progress: eaten / target, tint: palette.data.energy.color) {
                VStack {
                    Text(left, format: .number.precision(.fractionLength(0)))
                        .heliosFont(.display)
                        .foregroundStyle(palette.text.primary.color)
                        .heliosNumericTransition(value: left)
                    Text("kcal left").heliosFont(.caption).foregroundStyle(palette.text.secondary.color)
                }
            }
            .frame(width: ringSize, height: ringSize)
            HStack(spacing: HeliosTokens.space(3)) {
                Button("Log 250 kcal") {
                    eaten = min(eaten + 250, target)
                    toast = HeliosToast(symbol: "fork.knife", message: "Meal logged", haptic: .mealLogged)
                }
                .buttonStyle(.heliosPrimary)
                Button("Reset") { eaten = 1_260 }
                    .buttonStyle(.heliosSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .deepGlassCard(sheenTrigger: eaten)
        .heliosScrollDepth()
    }

    /// A personal record: sparks around the badge, a bounce on the symbol, a heavy tap and a spoken confirmation.
    private var record: some View {
        VStack(spacing: HeliosTokens.space(3)) {
            SectionHeader("Personal record")
            ZStack {
                Circle()
                    .fill(palette.accent.subtle.color)
                    .overlay { Circle().strokeBorder(palette.accent.base.color, lineWidth: 1.5) }
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(palette.accent.base.color)
                    .symbolEffect(.bounce, value: reduceMotion ? 0 : records)
                HeliosCelebration(trigger: records)
                    .frame(width: badgeSize * 1.8, height: badgeSize * 1.8)
            }
            .frame(width: badgeSize, height: badgeSize)
            .padding(HeliosTokens.space(5))
            .accessibilityHidden(true)
            Button("New bench record") {
                records += 1
                toast = HeliosToast(symbol: "trophy.fill", message: "New record: bench press", haptic: .personalRecord)
            }
            .buttonStyle(.heliosSecondary)
        }
        .frame(maxWidth: .infinity)
        .deepGlassCard(sheenTrigger: records)
        .heliosScrollDepth()
    }

    /// Bars draw in left to right, inside the 400 ms limit.
    private var week: some View {
        VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
            SectionHeader("Sample week")
            HStack(alignment: .bottom, spacing: HeliosTokens.space(2)) {
                ForEach(Array(weekly.enumerated()), id: \.offset) { _, share in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(palette.data.energy.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120 * share)
                }
            }
            .frame(height: 120, alignment: .bottom)
            .heliosDrawIn()
            .accessibilityElement()
            .accessibilityLabel(Text("Sample week, seven bars"))
            Text("Sample data for review only.")
                .heliosFont(.caption)
                .foregroundStyle(palette.text.secondary.color)
        }
        .deepGlassCard()
        .heliosScrollDepth()
    }

    /// Tappable tiles press in and spring back; they dim instead under Reduce Motion.
    private var tiles: some View {
        VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
            SectionHeader("Pressable tiles")
            Button {
                toast = HeliosToast(symbol: "syringe", message: "Dose logged", haptic: .doseLogged)
            } label: {
                MetricTile("Next dose", value: "8:00", unit: "PM", accent: palette.data.peptide.color)
            }
            .buttonStyle(.heliosPressable)
            Button {
                toast = HeliosToast(symbol: "checkmark.circle.fill", message: "Set complete", haptic: .setComplete)
            } label: {
                MetricTile("Squat", value: "3 × 5", unit: nil, accent: palette.data.training.color)
            }
            .buttonStyle(.heliosPressable)
        }
        .deepGlassCard()
        .heliosScrollDepth()
    }
}
#endif
