#if canImport(SwiftUI)
import SwiftUI

// MARK: Section header

public struct SectionHeader: View {
    private let title: LocalizedStringKey
    @Environment(\.heliosTheme) private var theme

    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .heliosFont(.section)
            .foregroundStyle(theme.palette.text.primary.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: Metric tile

/// A label, a number and its unit on a raised glass tile. At accessibility text sizes the unit drops below the value
/// instead of being squeezed or truncated.
public struct MetricTile: View {
    private let title: LocalizedStringKey
    private let value: String
    private let unit: String?
    private let accent: Color?
    @Environment(\.heliosTheme) private var theme

    public init(_ title: LocalizedStringKey, value: String, unit: String? = nil, accent: Color? = nil) {
        self.title = title
        self.value = value
        self.unit = unit
        self.accent = accent
    }

    public var body: some View {
        let palette = theme.palette
        VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
            HStack(spacing: HeliosTokens.space(2)) {
                if let accent {
                    Circle().fill(accent).frame(width: 8, height: 8).accessibilityHidden(true)
                }
                Text(title)
                    .heliosFont(.metricLabel)
                    .foregroundStyle(palette.text.secondary.color)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: HeliosTokens.space(1)) {
                    valueText
                    unitText
                }
                VStack(alignment: .leading, spacing: 0) {
                    valueText
                    unitText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(level: .raised, cornerRadius: HeliosTokens.radius.tile)
        .accessibilityElement(children: .combine)
    }

    private var valueText: some View {
        Text(value)
            .heliosFont(.metricValue)
            .foregroundStyle(theme.palette.text.primary.color)
    }

    @ViewBuilder
    private var unitText: some View {
        if let unit {
            Text(unit)
                .heliosFont(.caption)
                .foregroundStyle(theme.palette.text.secondary.color)
        }
    }
}

// MARK: Progress ring

/// A ring that fills towards a target, with arbitrary content in the middle. The percentage is always available to
/// VoiceOver, and the fill animates only when Reduce Motion is off.
public struct ProgressRing<Center: View>: View {
    private let progress: Double
    private let tint: Color
    private let lineWidth: Double
    private let center: Center
    @Environment(\.heliosTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progress: Double, tint: Color, lineWidth: Double = 10, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.tint = tint
        self.lineWidth = lineWidth
        self.center = center()
    }

    public var body: some View {
        let clamped = min(max(progress, 0), 1)
        let fillAnimation: Animation? = reduceMotion ? nil : Animation.easeOut(duration: HeliosTokens.motion.base)
        ZStack {
            Circle()
                .stroke(theme.palette.border.hairline.color, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(fillAnimation, value: clamped)
            center
        }
        .padding(lineWidth / 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(Int((clamped * 100).rounded())) percent"))
    }
}

// MARK: Buttons

public enum HeliosButtonKind: Sendable {
    /// Solid accent: the one main action on a screen.
    case primary
    /// Glass: everything else.
    case secondary
}

private struct HeliosButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: HeliosButtonKind
    @Environment(\.heliosTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: HeliosTokens.radius.button, style: .continuous)
        configuration.label
            .heliosFont(.bodyStrong)
            .foregroundStyle(kind == .primary ? palette.text.onAccent.color : palette.text.primary.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, HeliosTokens.space(5))
            .padding(.vertical, HeliosTokens.space(3))
            .frame(minHeight: HeliosTokens.minimumTapTarget)
            .background {
                switch kind {
                case .primary:
                    shape.fill(configuration.isPressed ? palette.accent.pressed.color : palette.accent.base.color)
                case .secondary:
                    GlassBackground(level: configuration.isPressed ? .overlay : .raised, cornerRadius: HeliosTokens.radius.button)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

public struct HeliosButtonStyle: ButtonStyle {
    private let kind: HeliosButtonKind

    public init(_ kind: HeliosButtonKind = .primary) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        HeliosButtonBody(configuration: configuration, kind: kind)
    }
}

extension ButtonStyle where Self == HeliosButtonStyle {
    public static var heliosPrimary: HeliosButtonStyle { HeliosButtonStyle(.primary) }
    public static var heliosSecondary: HeliosButtonStyle { HeliosButtonStyle(.secondary) }
}

// MARK: Chips and badges

/// A small label, optionally selectable. Selection is shown with a tint fill, a coloured edge and a check mark,
/// never by colour alone.
public struct HeliosChip: View {
    private let title: LocalizedStringKey
    private let isSelected: Bool
    @Environment(\.heliosTheme) private var theme

    public init(_ title: LocalizedStringKey, isSelected: Bool = false) {
        self.title = title
        self.isSelected = isSelected
    }

    public var body: some View {
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
        HStack(spacing: HeliosTokens.space(1)) {
            if isSelected {
                Image(systemName: "checkmark").accessibilityHidden(true)
            }
            Text(title).multilineTextAlignment(.leading)
        }
        .heliosFont(.callout)
        .foregroundStyle(isSelected ? palette.accent.base.color : palette.text.secondary.color)
        .padding(.horizontal, HeliosTokens.space(3))
        .padding(.vertical, HeliosTokens.space(2))
        .background {
            shape.fill(isSelected ? palette.accent.tint.color : palette.glass.raised.color)
        }
        .overlay {
            shape.strokeBorder(isSelected ? palette.accent.base.color : palette.border.hairline.color, lineWidth: isSelected ? 1.5 : 1)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public enum HeliosStatus: Sendable {
    case success, warning, danger

    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }
}

/// An icon plus text, so the status never depends on colour.
public struct StatusBadge: View {
    private let status: HeliosStatus
    private let title: LocalizedStringKey
    @Environment(\.heliosTheme) private var theme

    public init(_ status: HeliosStatus, _ title: LocalizedStringKey) {
        self.status = status
        self.title = title
    }

    public var body: some View {
        Label {
            Text(title).heliosFont(.footnote)
        } icon: {
            Image(systemName: status.symbol)
        }
        .foregroundStyle(tint)
    }

    private var tint: Color {
        let colors = theme.palette.status
        switch status {
        case .success: return colors.success.color
        case .warning: return colors.warning.color
        case .danger: return colors.danger.color
        }
    }
}
#endif
