import XCTest
@testable import HeliosDesign

final class DeepGlassAuditTests: XCTestCase {
    private func describe(_ findings: [AuditFinding]) -> String {
        findings.map { "\($0.severity) \($0.rule): \(String(format: "%.2f", $0.value)) < \(String(format: "%.2f", $0.required)) at \($0.detail)" }.joined(separator: "\n")
    }

    func testEveryShippedPaletteReadsOnDeepGlass() {
        for palette in HeliosPalette.all {
            let errors = DeepGlassAudit.audit(palette).filter { $0.severity == .error }
            XCTAssertEqual(errors, [], "\(palette.id):\n\(describe(errors))")
        }
    }

    func testPrimaryTextKeepsAAAOnDeepGlass() {
        for palette in HeliosPalette.all {
            let primary = DeepGlassAudit.audit(palette).filter { $0.rule.hasPrefix("text.primary") }
            XCTAssertEqual(primary, [], "\(palette.id): primary text should reach 7:1 on every deep surface\n\(describe(primary))")
        }
    }

    func testDepthNeverLowersContrastOnAnySurface() {
        for palette in HeliosPalette.all {
            for surface in DeepGlassAudit.surfaces(of: palette) {
                for check in DeepGlassAudit.checks(for: palette) {
                    let plain = ColorMath.contrastRatio(check.color, surface.plain)
                    let deep = ColorMath.contrastRatio(check.color, surface.deep)
                    XCTAssertGreaterThanOrEqual(deep, plain - 0.001, "\(palette.id) \(check.rule) at \(surface.name)")
                }
            }
        }
    }

    func testSurfacesCoverBackdropsLevelsNestingToastAndFallbacks() {
        let palette = HeliosPalette.dark
        let names = Set(DeepGlassAudit.surfaces(of: palette).map(\.name))
        let backdrops = PaletteAudit.backdrops(of: palette).count
        // Three levels and two nested panes per backdrop, the toast twice, and three opaque fallbacks.
        XCTAssertEqual(names.count, backdrops * 5 + 2 + 3)
        XCTAssertTrue(names.contains("deep overlay over glows-stacked/bottom"), "brightest Graphite backdrop, top level")
        XCTAssertTrue(names.contains("overlay on deep base over glows-stacked/bottom"), "pressed control on a deep card")
        XCTAssertTrue(names.contains("raised on deep base over glow0/top"))
        XCTAssertTrue(names.contains("toast"))
        XCTAssertTrue(names.contains("toast (opaque)"))
        XCTAssertTrue(names.contains("deep overlay (opaque)"))
    }

    func testFallbacksDrawNoLayersAndNoSheen() {
        for palette in HeliosPalette.all {
            XCTAssertEqual(DeepGlassComposition.layers(for: palette, reduceTransparency: true), [], "\(palette.id): Reduce Transparency stays the audited opaque surface")
            XCTAssertFalse(DeepGlassComposition.allowsSheen(palette: palette, reduceTransparency: true, reduceMotion: false))
            XCTAssertFalse(DeepGlassComposition.allowsSheen(palette: palette, reduceTransparency: false, reduceMotion: true))
            for surface in DeepGlassAudit.surfaces(of: palette) where surface.name.hasSuffix("(opaque)") {
                XCTAssertEqual(surface.deep, surface.plain, "\(palette.id) \(surface.name)")
            }
        }
        for palette in [HeliosPalette.darkHighContrast, .lightHighContrast] {
            XCTAssertEqual(DeepGlassComposition.layers(for: palette, reduceTransparency: false), [], "Increase Contrast keeps the strong edge as the only cue")
            XCTAssertFalse(DeepGlassComposition.allowsSheen(palette: palette, reduceTransparency: false, reduceMotion: false))
        }
        XCTAssertTrue(DeepGlassComposition.allowsSheen(palette: .dark, reduceTransparency: false, reduceMotion: false))
    }

    func testLayersMoveAwayFromTheTextAndAddNoTint() {
        let graphite = DeepGlassComposition.layers(for: .dark, reduceTransparency: false)
        XCTAssertEqual(graphite.map(\.placement), [.bottomShade])
        XCTAssertLessThan(ColorMath.relativeLuminance(graphite[0].color.withAlpha(1)), ColorMath.relativeLuminance(HeliosPalette.dark.text.tertiary))
        let frost = DeepGlassComposition.layers(for: .light, reduceTransparency: false)
        XCTAssertEqual(frost.map(\.placement), [.topLight])
        XCTAssertGreaterThan(ColorMath.relativeLuminance(frost[0].color.withAlpha(1)), ColorMath.relativeLuminance(HeliosPalette.light.text.tertiary))
        for layer in graphite + frost {
            XCTAssertNotEqual(layer.color.withAlpha(1), HeliosPalette.dark.accent.base.withAlpha(1), "an accent wash means selected")
            XCTAssertNotEqual(layer.color.withAlpha(1), HeliosPalette.light.accent.base.withAlpha(1), "an accent wash means selected")
        }
    }

    func testToastSitsOnTheOpaqueOverlayTone() {
        for palette in HeliosPalette.all {
            XCTAssertEqual(DeepGlassComposition.toastBase(for: palette, reduceTransparency: true), palette.opaque.overlay)
            XCTAssertEqual(DeepGlassComposition.toastBase(for: palette, reduceTransparency: false).alpha, 1, accuracy: 1e-9, "nothing shows through a toast")
        }
    }

    func testSheenIsAnAccentEdgeGlint() {
        XCTAssertEqual(DeepGlassComposition.sheenColor(for: .dark), HeliosPalette.dark.accent.base)
        XCTAssertLessThanOrEqual(DeepGlassComposition.sheenLineWidth, HeliosTokens.space(1), "edge only, inside the card padding")
    }

    // MARK: the audit must actually catch problems

    func testAuditCatchesTheFirstDraftsBrightGraphiteDepth() {
        // The unmeasured first draft: white top light at 55% of the highlight plus a 10% accent wash, and a white
        // sheen across the face. Measured here, it fails Graphite text and chart contrast.
        let highlight = HeliosPalette.dark.border.highlight
        let draft = [
            DeepGlassLayer(placement: .topLight, color: highlight.withAlpha(highlight.alpha * 0.55)),
            DeepGlassLayer(placement: .topLight, color: HeliosPalette.dark.accent.base.withAlpha(0.10)),
            DeepGlassLayer(placement: .topLight, color: highlight),
        ]
        let findings = DeepGlassAudit.audit(.dark, layers: draft)
        XCTAssertTrue(findings.contains { $0.rule == "text.tertiary on deep glass" && $0.severity == .error }, describe(findings))
        XCTAssertTrue(findings.contains { $0.rule == "data.carbs (graphic) on deep glass" && $0.severity == .error }, describe(findings))
        XCTAssertTrue(findings.contains { $0.rule == "text.primary lowered by deep glass" }, describe(findings))
    }

    func testAuditCatchesATintThatLowersFrostContrast() {
        // A faint accent wash still passes the minimums in Frost, but it costs contrast, which deep glass may not do.
        let wash = [DeepGlassLayer(placement: .topLight, color: HeliosPalette.light.accent.base.withAlpha(0.07))]
        let findings = DeepGlassAudit.audit(.light, layers: wash)
        XCTAssertTrue(findings.contains { $0.rule == "text.tertiary lowered by deep glass" && $0.severity == .error }, describe(findings))
    }

    func testChecksMatchPaletteAuditRoles() {
        let rules = DeepGlassAudit.checks(for: .dark).map(\.rule)
        XCTAssertEqual(rules.count, 8 + DataColors.names.count)
        XCTAssertTrue(rules.contains("text.tertiary"))
        XCTAssertTrue(rules.contains("data.carbs (graphic)"))
        XCTAssertEqual(DeepGlassAudit.checks(for: .dark).first { $0.rule == "text.primary" }?.advisory, 7.0)
    }
}
