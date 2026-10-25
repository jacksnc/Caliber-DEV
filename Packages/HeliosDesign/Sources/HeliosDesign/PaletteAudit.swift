import Foundation

public struct AuditFinding: Hashable, Sendable {
    public enum Severity: String, Sendable { case error, warning }

    public let severity: Severity
    public let rule: String
    /// The worst value found (contrast ratio or colour distance).
    public let value: Double
    public let required: Double
    /// Where the worst case occurs, e.g. "overlay over cumulative/bottom".
    public let detail: String
}

/// Checks a palette against the accessibility rules the design depends on. It is the reason the tokens can claim
/// "readable on glass": translucent surfaces are composited over every backdrop they can meet, and the worst case counts.
public enum PaletteAudit {
    // MARK: Backdrops and surfaces

    /// Every backdrop the glass can sit on: each canvas end, each glow at its own height and at both ends, and all
    /// glows stacked (a pessimistic bound; the real overlap is never stronger).
    public static func backdrops(of palette: HeliosPalette) -> [String: RGBA] {
        var result: [String: RGBA] = ["canvas/top": palette.canvasTop, "canvas/bottom": palette.canvasBottom]
        for (index, glow) in palette.glows.enumerated() {
            let tint = glow.color.withAlpha(glow.opacity)
            result["glow\(index)/at-height"] = tint.composited(over: palette.canvasTop.mixed(with: palette.canvasBottom, amount: glow.y))
            result["glow\(index)/top"] = tint.composited(over: palette.canvasTop)
            result["glow\(index)/bottom"] = tint.composited(over: palette.canvasBottom)
        }
        for (name, start) in [("top", palette.canvasTop), ("bottom", palette.canvasBottom)] {
            result["glows-stacked/\(name)"] = palette.glows.reduce(start) { $1.color.withAlpha($1.opacity).composited(over: $0) }
        }
        return result
    }

    /// Glass levels composited over every backdrop.
    public static func glassSurfaces(of palette: HeliosPalette) -> [String: RGBA] {
        var result: [String: RGBA] = [:]
        for (backdropName, backdrop) in backdrops(of: palette) {
            for level in GlassLevel.allCases {
                result["\(level.rawValue) over \(backdropName)"] = palette.glass[level].composited(over: backdrop)
            }
        }
        return result
    }

    /// The Reduce Transparency fallback surfaces.
    public static func opaqueSurfaces(of palette: HeliosPalette) -> [String: RGBA] {
        Dictionary(uniqueKeysWithValues: GlassLevel.allCases.map { ("\($0.rawValue) (opaque)", palette.opaque[$0]) })
    }

    // MARK: Audit

    private static func worstContrast(of color: RGBA, on surfaces: [String: RGBA]) -> (ratio: Double, where: String) {
        var worst = (ratio: Double.infinity, where: "")
        for (name, surface) in surfaces.sorted(by: { $0.key < $1.key }) {
            let ratio = ColorMath.contrastRatio(color, surface)
            if ratio < worst.ratio { worst = (ratio, name) }
        }
        return worst
    }

    /// All violations (errors) and notes (warnings); an empty result means the palette passes.
    public static func audit(_ palette: HeliosPalette) -> [AuditFinding] {
        var findings: [AuditFinding] = []
        let glass = glassSurfaces(of: palette)
        let opaque = opaqueSurfaces(of: palette)

        struct Check {
            let rule: String
            let color: RGBA
            let minimum: Double
            let advisory: Double?
        }
        let checks: [Check] = [
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

        for (surfaceKind, surfaces) in [("glass", glass), ("opaque", opaque)] {
            for check in checks {
                let worst = worstContrast(of: check.color, on: surfaces)
                if worst.ratio < check.minimum {
                    findings.append(AuditFinding(severity: .error, rule: "\(check.rule) on \(surfaceKind)", value: worst.ratio, required: check.minimum, detail: worst.where))
                } else if let advisory = check.advisory, worst.ratio < advisory {
                    findings.append(AuditFinding(severity: .warning, rule: "\(check.rule) on \(surfaceKind)", value: worst.ratio, required: advisory, detail: worst.where))
                }
            }
        }

        // Text on a solid accent fill (primary buttons).
        let onAccent = ColorMath.contrastRatio(palette.text.onAccent, palette.accent.base)
        if onAccent < 4.5 {
            findings.append(AuditFinding(severity: .error, rule: "text.onAccent on accent.base", value: onAccent, required: 4.5, detail: "button label"))
        }

        // Increased-contrast palettes must give controls an edge a low-vision user can find.
        if palette.isHighContrast {
            var worst = (ratio: Double.infinity, where: "")
            for (name, surface) in glass.sorted(by: { $0.key < $1.key }) {
                let edge = palette.border.strong.composited(over: surface)
                let ratio = ColorMath.contrastRatio(edge, surface)
                if ratio < worst.ratio { worst = (ratio, name) }
            }
            if worst.ratio < 3.0 {
                findings.append(AuditFinding(severity: .error, rule: "border.strong (control edge)", value: worst.ratio, required: 3.0, detail: worst.where))
            }
        }

        // Series colours must read as colours (not grey), sit in a lightness band that works on the surface, and
        // stay apart. Bands are OKLCH lightness: 0.48-0.67 on dark surfaces, 0.43-0.77 on light ones; chroma at least 0.10.
        let band = palette.isDark ? 0.48...0.67 : 0.43...0.77
        for name in DataColors.hueNames {
            guard let color = palette.data.color(named: name) else { continue }
            let lab = ColorMath.oklab(color)
            if !band.contains(lab.lightness) {
                findings.append(AuditFinding(severity: .error, rule: "data.\(name) lightness band", value: lab.lightness, required: palette.isDark ? 0.48 : 0.43, detail: "OKLCH L must be in \(band.lowerBound)-\(band.upperBound)"))
            }
            if lab.chroma < 0.10 {
                findings.append(AuditFinding(severity: .error, rule: "data.\(name) chroma floor", value: lab.chroma, required: 0.10, detail: "reads as grey"))
            }
        }

        // Chart colours that can share a chart must stay apart, for everyone and under red-green colour-vision deficiency.
        for group in HeliosTokens.chartGroups {
            let colors = group.members.compactMap { palette.data.color(named: $0) }
            guard colors.count == group.members.count else {
                findings.append(AuditFinding(severity: .error, rule: "chart group \(group.name)", value: 0, required: group.minNormal, detail: "unknown member"))
                continue
            }
            let normal = ColorMath.minimumSeparation(colors)
            if normal < group.minNormal {
                findings.append(AuditFinding(severity: .error, rule: "chart group \(group.name) separation", value: normal, required: group.minNormal, detail: "normal vision"))
            }
            for deficiency in [ColorMath.ColorVisionDeficiency.protanopia, .deuteranopia] {
                let separation = ColorMath.minimumSeparation(colors, under: deficiency)
                if separation < group.minCVD {
                    findings.append(AuditFinding(severity: .error, rule: "chart group \(group.name) separation", value: separation, required: group.minCVD, detail: deficiency.rawValue))
                }
            }
            let tritan = ColorMath.minimumSeparation(colors, under: .tritanopia)
            if tritan < group.minCVD {
                findings.append(AuditFinding(severity: .warning, rule: "chart group \(group.name) separation", value: tritan, required: group.minCVD, detail: "tritanopia (label the series)"))
            }
        }
        return findings
    }
}
