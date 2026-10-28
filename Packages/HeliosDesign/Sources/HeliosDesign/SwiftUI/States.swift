#if canImport(SwiftUI)
import SwiftUI

// MARK: Segmented control parts

/// The track behind a row of segments: raised glass with a hairline, the opaque fallback under Reduce Transparency and
/// a strong 1.5 pt edge under Increase Contrast. Callers keep their own buttons, labels and identifiers.
public struct HeliosSegmentTrack: View {
    private let cornerRadius: Double
    @Environment(\.heliosTheme) private var theme

    public init(cornerRadius: Double = 16) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(theme.reduceTransparency ? palette.opaque.raised.color : palette.glass.raised.color)
            .overlay {
                shape.strokeBorder(
                    palette.isHighContrast ? palette.border.strong.color : palette.border.hairline.color,
                    lineWidth: palette.isHighContrast ? 1.5 : 1
                )
            }
            .accessibilityHidden(true)
    }
}

/// The selected segment: an accent wash and a 1.5 pt accent edge. Pair it with accent label text and the
/// `.isSelected` trait so selection is never shown by fill alone.
public struct HeliosSegmentHighlight: View {
    private let cornerRadius: Double
    @Environment(\.heliosTheme) private var theme

    public init(cornerRadius: Double = 12) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(theme.palette.accent.subtle.color)
            .overlay { shape.strokeBorder(theme.palette.accent.base.color, lineWidth: 1.5) }
            .accessibilityHidden(true)
    }
}

// MARK: Empty state

/// An icon, a heading, one honest sentence and an optional action, for a card that has nothing to show yet. The icon
/// moves above the text at accessibility sizes so the heading keeps the full width. The heading and message stay
/// separate accessibility elements, so VoiceOver reads them in order and the action stays reachable.
public struct HeliosEmptyState<Actions: View>: View {
    private let symbol: String
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let actions: Actions
    @Environment(\.heliosTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var badgeSize = 40.0

    public init(
        symbol: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        @ViewBuilder actions: () -> Actions
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actions = actions()
    }

    public var body: some View {
        let palette = theme.palette
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: HeliosTokens.space(3)))
            : AnyLayout(HStackLayout(alignment: .top, spacing: HeliosTokens.space(3)))
        VStack(alignment: .leading, spacing: HeliosTokens.space(4)) {
            layout {
                Image(systemName: symbol)
                    .heliosFont(.section)
                    .foregroundStyle(palette.accent.base.color)
                    .frame(width: badgeSize, height: badgeSize)
                    .background { Circle().fill(palette.accent.subtle.color) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
                    Text(title)
                        .heliosFont(.section)
                        .foregroundStyle(palette.text.primary.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .heliosFont(.callout)
                        .foregroundStyle(palette.text.secondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension HeliosEmptyState where Actions == EmptyView {
    public init(symbol: String, title: LocalizedStringKey, message: LocalizedStringKey) {
        self.init(symbol: symbol, title: title, message: message) { EmptyView() }
    }
}
#endif
