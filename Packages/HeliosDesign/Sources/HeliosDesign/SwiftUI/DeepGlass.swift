#if canImport(SwiftUI)
import SwiftUI

// MARK: Depth

/// Thickness for a glass pane: light caught along the top edge and a faint accent refraction in the corner nearest the
/// canvas glow. Static, so Reduce Motion needs nothing. It draws nothing under Reduce Transparency (the pane is opaque)
/// or Increase Contrast (the strong edge is the cue there), so the audited fallbacks are untouched.
public struct HeliosGlassDepth: View {
    private let cornerRadius: Double
    @Environment(\.heliosTheme) private var theme

    public init(cornerRadius: Double = HeliosTokens.radius.card) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let palette = theme.palette
        if !theme.reduceTransparency && !palette.isHighContrast {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let highlight = palette.border.highlight.color
            ZStack {
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: highlight.opacity(0.55), location: 0),
                            .init(color: highlight.opacity(0), location: 0.38),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Graphite's ambient glow sits top left and Frost's top right; the refraction follows it.
                shape.fill(
                    RadialGradient(
                        colors: [palette.accent.base.color.opacity(palette.isDark ? 0.10 : 0.07), palette.accent.base.color.opacity(0)],
                        center: palette.isDark ? .topLeading : .topTrailing,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: Sheen

/// A single band of light that sweeps across the pane each time `trigger` changes: a logged meal, a dose taken, a
/// goal reached. It never loops and never plays on its own. Nothing is drawn under Reduce Motion, Reduce Transparency
/// or Increase Contrast. Place it behind content (it is part of `deepGlassCard`) so text is never washed out.
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
        if HeliosMotionPolicy(reduceMotion: reduceMotion).allowsFlourish
            && !theme.reduceTransparency && !theme.palette.isHighContrast {
            let glint = theme.palette.border.highlight.color
            let radius = cornerRadius
            // The band's centre runs along the diagonal from -0.5 (past the top-left corner) to 1.5 (past the
            // bottom-right), so it is invisible both at rest and when the sweep ends.
            Color.clear
                .keyframeAnimator(initialValue: -0.5, trigger: trigger) { view, position in
                    view.overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [glint.opacity(0), glint, glint.opacity(0)],
                                    startPoint: UnitPoint(x: position - 0.3, y: position - 0.3),
                                    endPoint: UnitPoint(x: position + 0.3, y: position + 0.3)
                                )
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

    /// `glassCard` with depth, plus a light sweep each time `sheenTrigger` changes.
    public func deepGlassCard<T: Equatable>(
        level: GlassLevel = .base,
        cornerRadius: Double = HeliosTokens.radius.card,
        padding: Double = HeliosTokens.spacing[3],
        sheenTrigger: T
    ) -> some View {
        self
            .padding(padding)
            .background { HeliosDeepGlass(level: level, cornerRadius: cornerRadius, sheenTrigger: sheenTrigger) }
    }
}
#endif
