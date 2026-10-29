import Foundation

/// `PaletteAudit` for deep glass: the same colours and minimums, measured on every surface deep glass can produce, with
/// each decorative layer at its peak. It also enforces the composition rule: no layer may lower the contrast of any
/// audited colour on any surface, compared with the same surface without the layers.
public enum DeepGlassAudit {
    /// A surface as plain glass would draw it and as deep glass draws it.
    public struct Surface: Hashable, Sendable {
        public let name: String
        public let plain: RGBA
        public let deep: RGBA
    }

    /// Every surface deep glass can produce for `palette`:
    /// - a deep pane of each glass level over every `PaletteAudit` backdrop;
    /// - a raised tile, and an overlay (a pressed control or a menu), drawn as plain glass on a deep card, over every
    ///   backdrop: the heaviest stack the deep-glass primitives create;
    /// - the toast surface, under normal settings and under Reduce Transparency;
    /// - the Reduce Transparency fallback of each level, where deep glass must add nothing.
    public static func surfaces(of palette: HeliosPalette, layers: [DeepGlassLayer]? = nil) -> [Surface] {
        let layers = layers ?? DeepGlassComposition.layers(for: palette, reduceTransparency: false)
        var result: [Surface] = []
        for (backdropName, backdrop) in PaletteAudit.backdrops(of: palette).sorted(by: { $0.key < $1.key }) {
            for level in GlassLevel.allCases {
                let plain = palette.glass[level].composited(over: backdrop)
                let deep = DeepGlassComposition.peak(of: plain, layers: layers)
                result.append(Surface(name: "deep \(level.rawValue) over \(backdropName)", plain: plain, deep: deep))
            }
            let plainCard = palette.glass[.base].composited(over: backdrop)
            let deepCard = DeepGlassComposition.peak(of: plainCard, layers: layers)
            for level in [GlassLevel.raised, .overlay] {
                result.append(Surface(
                    name: "\(level.rawValue) on deep base over \(backdropName)",
                    plain: palette.glass[level].composited(over: plainCard),
                    deep: palette.glass[level].composited(over: deepCard)
                ))
            }
        }
        let toast = DeepGlassComposition.toastBase(for: palette, reduceTransparency: false)
        result.append(Surface(name: "toast", plain: toast, deep: DeepGlassComposition.peak(of: toast, layers: layers)))
        let opaqueLayers = DeepGlassComposition.layers(for: palette, reduceTransparency: true)
        let opaqueToast = DeepGlassComposition.toastBase(for: palette, reduceTransparency: true)
        result.append(Surface(name: "toast (opaque)", plain: opaqueToast, deep: DeepGlassComposition.peak(of: opaqueToast, layers: opaqueLayers)))
        for level in GlassLevel.allCases {
            let opaque = palette.opaque[level]
            result.append(Surface(name: "deep \(level.rawValue) (opaque)", plain: opaque, deep: DeepGlassComposition.peak(of: opaque, layers: opaqueLayers)))
        }
        return result
    }

    struct Check {
        let rule: String
        let color: RGBA
        let minimum: Double
        let advisory: Double?
    }

    /// The colours and minimums `PaletteAudit` holds glass surfaces to.
    static func checks(for palette: HeliosPalette) -> [Check] {
        [
            Check(rule: "text.primary", color: palette.text.primary, minimum: 4.5, advisory: 7.0),
            Check(rule: "text.secondary", color: palette.text.secondary, minimum: 4.5, advisory: nil),
            Check(rule: "text.tertiary", color: palette.text.tertiary, minimum: 4.5, advisory: nil),
            Check(rule: "accent.base as text or icon", color: palette.accent.base, minimum: 4.5, advisory: nil),
            Check(rule: "accent.focus ring", color: palette.accent.focus, minimum: 3.0, advisory: nil),
            Check(rule: "status.success", color: palette.status.success, minimum: 4.5, advisory: nil),
            Check(rule: "status.warning", color: palette.status.warning, minimum: 4.5, advisory: nil),
            Check(rule: "status.danger", color: palette.status.danger, minimum: 4.5, advisory: nil),
        ] + DataColors.names.compactMap { name in
            palette.data.color(named: name).map { Check(rule: "data.\(name) (graphic)", color: $0, minimum: 3.0, advisory: nil) }
        }
    }

    /// All violations (errors) and notes (warnings) for deep glass on `palette`; empty means it passes. Pass `layers`
    /// to audit a proposed composition instead of the shipped one.
    public static func audit(_ palette: HeliosPalette, layers: [DeepGlassLayer]? = nil) -> [AuditFinding] {
        var findings: [AuditFinding] = []
        let surfaces = surfaces(of: palette, layers: layers)
        for check in checks(for: palette) {
            var worst = (ratio: Double.infinity, where: "")
            var worstDrop = (amount: 0.0, plain: 0.0, where: "")
            for surface in surfaces {
                let ratio = ColorMath.contrastRatio(check.color, surface.deep)
                if ratio < worst.ratio { worst = (ratio, surface.name) }
                let plain = ColorMath.contrastRatio(check.color, surface.plain)
                if plain - ratio > worstDrop.amount { worstDrop = (plain - ratio, plain, surface.name) }
            }
            if worst.ratio < check.minimum {
                findings.append(AuditFinding(severity: .error, rule: "\(check.rule) on deep glass", value: worst.ratio, required: check.minimum, detail: worst.where))
            } else if let advisory = check.advisory, worst.ratio < advisory {
                findings.append(AuditFinding(severity: .warning, rule: "\(check.rule) on deep glass", value: worst.ratio, required: advisory, detail: worst.where))
            }
            // Rounding noise aside, a decorative layer must never cost contrast.
            if worstDrop.amount > 0.001 {
                findings.append(AuditFinding(
                    severity: .error,
                    rule: "\(check.rule) lowered by deep glass",
                    value: worstDrop.plain - worstDrop.amount,
                    required: worstDrop.plain,
                    detail: worstDrop.where
                ))
            }
        }

        // Increased-contrast palettes keep a findable control edge on every deep surface.
        if palette.isHighContrast {
            var worst = (ratio: Double.infinity, where: "")
            for surface in surfaces {
                let ratio = ColorMath.contrastRatio(palette.border.strong.composited(over: surface.deep), surface.deep)
                if ratio < worst.ratio { worst = (ratio, surface.name) }
            }
            if worst.ratio < 3.0 {
                findings.append(AuditFinding(severity: .error, rule: "border.strong (control edge) on deep glass", value: worst.ratio, required: 3.0, detail: worst.where))
            }
        }
        return findings
    }
}
