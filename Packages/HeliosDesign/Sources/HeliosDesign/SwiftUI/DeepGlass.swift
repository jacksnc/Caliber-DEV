#if canImport(SwiftUI)
import SwiftUI

// MARK: Depth

/// Thickness for a glass pane, drawn from `DeepGlassComposition` so `DeepGlassAudit` measures exactly this: Frost
/// catches light along the top edge, Graphite gathers shade towards the bottom edge. Each layer moves the surface away
/// from the text on it, so contrast only ever rises. Static, so Reduce Motion needs nothing. Nothing is drawn under
/// Reduce Transparency (the pane is opaque) or Increase Contrast (the strong edge is the cue there).
public struct HeliosGlassDepth: View {
    private let cornerRadius: Double
    @Environment(\.heliosTheme) private var theme

    public init(cornerRadius: Double = HeliosTokens.radius.card) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let layers = DeepGlassComposition.layers(for: theme.palette, reduceTransparency: theme.reduceTransparency)
        if !layers.isEmpty {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack {
                ForEach(layers, id: \.self) { layer in
                    shape.fill(Self.gradient(for: layer))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private static func gradient(for layer: DeepGlassLayer) -> LinearGradient {
        let peak = layer.color.color
        let clear = layer.color.withAlpha(0).color
        switch layer.placement {
        case .topLight:
            return LinearGradient(
                stops: [.init(color: peak, location: 0), .init(color: clear, location: DeepGlassComposition.topLightFade)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .bottomShade:
            return LinearGradient(
                stops: [.init(color: clear, location: DeepGlassComposition.bottomShadeStart), .init(color: peak, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: Sheen

/// A glint in the accent colour that runs once along the pane's edge each time `trigger` changes, after a confirmed
/// save such as a logged meal. It never loops, never plays on its own and never crosses the face of the pane, so it
/// can't sit behind text (content stays inside the card padding). Nothing is drawn under Reduce Motion, Reduce
/// Transparency or Increase Contrast.
public struct HeliosGlassSheen<Trigger: Equatable>: View {
    private let trigger: Trigger
    private let cornerRadius: Double
    @Environment(\.heliosTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(trigger: Trigger, cornerRadius: Double = HeliosTokens.radius.card) {
        self.trigger = trigger
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let palette = theme.palette
        if DeepGlassComposition.allowsSheen(palette: palette, reduceTransparency: theme.reduceTransparency, reduceMotion: reduceMotion) {
            let glint = DeepGlassComposition.sheenColor(for: palette).color
            let radius = cornerRadius
            let lineWidth = DeepGlassComposition.sheenLineWidth
            // The glint's centre runs along the diagonal from -0.5 (past the top-left corner) to 1.5 (past the
            // bottom-right), so it is invisible both at rest and when the sweep ends.
            Color.clear
                .keyframeAnimator(initialValue: -0.5, trigger: trigger) { view, position in
                    view.overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [glint.opacity(0), glint, glint.opacity(0)],
                                    startPoint: UnitPoint(x: position - 0.3, y: position - 0.3),
                                    endPoint: UnitPoint(x: position + 0.3, y: position + 0.3)
                                ),
                                lineWidth: lineWidth
                            )
                    }
                } keyframes: { _ in
                    CubicKeyframe(1.5, duration: HeliosTokens.motion.slow * 1.6)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: Deep glass

/// The standard glass pane plus depth and an optional sheen. Same tokens, shadow and fallbacks as `GlassBackground`.
public struct HeliosDeepGlass<Trigger: Equatable>: View {
    private let level: GlassLevel
    private let cornerRadius: Double
    private let sheenTrigger: Trigger

    public init(level: GlassLevel = .base, cornerRadius: Double = HeliosTokens.radius.card, sheenTrigger: Trigger) {
        self.level = level
        self.cornerRadius = cornerRadius
        self.sheenTrigger = sheenTrigger
    }

    public var body: some View {
        ZStack {
            GlassBackground(level: level, cornerRadius: cornerRadius)
            HeliosGlassDepth(cornerRadius: cornerRadius)
            HeliosGlassSheen(trigger: sheenTrigger, cornerRadius: cornerRadius)
        }
    }
}

extension HeliosDeepGlass where Trigger == Int {
    /// Depth without a sheen.
    public init(level: GlassLevel = .base, cornerRadius: Double = HeliosTokens.radius.card) {
        self.init(level: level, cornerRadius: cornerRadius, sheenTrigger: 0)
    }
}

extension View {
    /// `glassCard` with depth: a drop-in replacement where a hero card should feel thicker than its neighbours.
    public func deepGlassCard(
        level: GlassLevel = .base,
        cornerRadius: Double = HeliosTokens.radius.card,
        padding: Double = HeliosTokens.spacing[3]
    ) -> some View {
        deepGlassCard(level: level, cornerRadius: cornerRadius, padding: padding, sheenTrigger: 0)
    }

    /// `glassCard` with depth, plus an edge glint each time `sheenTrigger` changes. Change the trigger only after the
    /// save it marks has succeeded. Padding is at least the glint's line width, so content never meets the edge.
    public func deepGlassCard<T: Equatable>(
        level: GlassLevel = .base,
        cornerRadius: Double = HeliosTokens.radius.card,
        padding: Double = HeliosTokens.spacing[3],
        sheenTrigger: T
    ) -> some View {
        self
            .padding(max(padding, DeepGlassComposition.sheenLineWidth))
            .background { HeliosDeepGlass(level: level, cornerRadius: cornerRadius, sheenTrigger: sheenTrigger) }
    }
}
#endif
