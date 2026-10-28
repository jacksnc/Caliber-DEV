#if canImport(SwiftUI)
import SwiftUI

/// A translucent token tint, lit edge and soft shadow; floating overlays add a restrained system blur.
/// With Reduce Transparency it becomes an opaque surface of the same tone; with Increase Contrast it gets a strong edge.
public struct GlassBackground: View {
    private let level: GlassLevel
    private let cornerRadius: Double
    @Environment(\.heliosTheme) private var theme

    public init(level: GlassLevel = .base, cornerRadius: Double = HeliosTokens.radius.card) {
        self.level = level
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if theme.reduceTransparency {
                shape.fill(palette.opaque[level].color)
            } else {
                // The canvas already supplies soft, static ambient light. A full
                // system material adds an un-tokened neutral tint (especially on
                // recent iOS), turning Graphite cards gray. Use the audited tint
                // directly; floating overlays retain a restrained backdrop blur.
                if level == .overlay {
                    shape.fill(.ultraThinMaterial).opacity(0.15)
                }
                shape.fill(palette.glass[level].color)
            }
        }
        .overlay {
            if palette.isHighContrast {
                shape.strokeBorder(palette.border.strong.color, lineWidth: 1.5)
            } else {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [palette.border.highlight.color, palette.border.lowlight.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
        }
        .shadow(color: palette.shadow.color.color, radius: palette.shadow.radius, x: 0, y: palette.shadow.y)
    }
}

extension View {
    /// Pads the content and puts it on glass.
    public func glassCard(
        level: GlassLevel = .base,
        cornerRadius: Double = HeliosTokens.radius.card,
        padding: Double = HeliosTokens.spacing[3]
    ) -> some View {
        self
            .padding(padding)
            .background { GlassBackground(level: level, cornerRadius: cornerRadius) }
    }
}
#endif
