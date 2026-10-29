import Foundation

/// One decorative layer that deep glass draws over a glass surface. It is stated as data so `DeepGlassAudit` measures
/// exactly what `HeliosGlassDepth` draws. `color` carries the layer's peak alpha; the view fades it out across the pane.
public struct DeepGlassLayer: Hashable, Sendable {
    public enum Placement: String, Sendable {
        /// Peak at the top edge, fully faded by `DeepGlassComposition.topLightFade` of the height.
        case topLight
        /// Clear above `DeepGlassComposition.bottomShadeStart` of the height, peak at the bottom edge.
        case bottomShade
    }

    public let placement: Placement
    public let color: RGBA

    public init(placement: Placement, color: RGBA) {
        self.placement = placement
        self.color = color
    }
}

/// What deep glass adds to a pane, and the rule that keeps it readable: a layer may only move the surface away from
/// the text drawn on it. Frost (dark text) gets light caught along the top edge; Graphite (light text) gets a shade
/// gathering at the bottom edge. Neither theme gets a tint, because an accent wash already means "selected" in Helios.
/// Under Reduce Transparency or Increase Contrast there are no layers at all.
public enum DeepGlassComposition {
    public static let topLightFade = 0.38
    public static let bottomShadeStart = 0.5
    /// Share of the palette's highlight alpha used for Frost's top light.
    public static let topLightStrength = 0.55
    /// Peak alpha of Graphite's bottom shade, in the darkest canvas tone.
    public static let bottomShadeAlpha = 0.30
    /// The sheen is a glint that runs along the pane's edge, never across its face, so it never sits behind text.
    public static let sheenLineWidth = 1.5

    public static func layers(for palette: HeliosPalette, reduceTransparency: Bool) -> [DeepGlassLayer] {
        guard !reduceTransparency, !palette.isHighContrast else { return [] }
        if palette.isDark {
            return [DeepGlassLayer(placement: .bottomShade, color: palette.canvasTop.withAlpha(bottomShadeAlpha))]
        }
        let highlight = palette.border.highlight
        return [DeepGlassLayer(placement: .topLight, color: highlight.withAlpha(highlight.alpha * topLightStrength))]
    }

    /// Every layer at its peak over `surface`: the pessimistic point of the pane.
    public static func peak(of surface: RGBA, layers: [DeepGlassLayer]) -> RGBA {
        layers.reduce(surface) { $1.color.composited(over: $0) }
    }

    /// A toast floats over scrolling content that no canvas audit can predict, so it sits on the opaque overlay tone
    /// with the overlay glass tint on top, rather than on see-through glass. Under Reduce Transparency the tint is opaque.
    public static func toastBase(for palette: HeliosPalette, reduceTransparency: Bool) -> RGBA {
        reduceTransparency ? palette.opaque.overlay : palette.glass.overlay.composited(over: palette.opaque.overlay)
    }

    public static func sheenColor(for palette: HeliosPalette) -> RGBA {
        palette.accent.base
    }

    /// The sheen is movement and a see-through effect, and it would compete with the strong edge, so any one of these
    /// settings removes it.
    public static func allowsSheen(palette: HeliosPalette, reduceTransparency: Bool, reduceMotion: Bool) -> Bool {
        !reduceMotion && !reduceTransparency && !palette.isHighContrast
    }
}
