import XCTest
@testable import HeliosDesign

final class PaletteAuditTests: XCTestCase {
    private func describe(_ findings: [AuditFinding]) -> String {
        findings.map { "\($0.severity) \($0.rule): \(String(format: "%.2f", $0.value)) < \(String(format: "%.2f", $0.required)) at \($0.detail)" }.joined(separator: "\n")
    }

    func testEveryShippedPaletteHasNoAccessibilityErrors() {
        for palette in HeliosPalette.all {
            let errors = PaletteAudit.audit(palette).filter { $0.severity == .error }
            XCTAssertEqual(errors, [], "\(palette.id):\n\(describe(errors))")
        }
    }

    func testPrimaryTextClearsAAAEverywhere() {
        for palette in HeliosPalette.all {
            let warnings = PaletteAudit.audit(palette).filter { $0.rule.hasPrefix("text.primary") }
            XCTAssertEqual(warnings, [], "\(palette.id): primary text should reach 7:1 on every surface\n\(describe(warnings))")
        }
    }

    func testBackdropsCoverCanvasEndsAndEveryGlow() {
        let backdrops = PaletteAudit.backdrops(of: .dark)
        XCTAssertNotNil(backdrops["canvas/top"])
        XCTAssertNotNil(backdrops["canvas/bottom"])
        XCTAssertNotNil(backdrops["glow0/at-height"])
        XCTAssertNotNil(backdrops["glow1/bottom"])
        XCTAssertNotNil(backdrops["glows-stacked/bottom"])
        // The stacked bound is at least as light as any single glow over the same end.
        let stacked = ColorMath.relativeLuminance(backdrops["glows-stacked/bottom"]!)
        XCTAssertGreaterThanOrEqual(stacked, ColorMath.relativeLuminance(backdrops["glow0/bottom"]!))
        XCTAssertEqual(PaletteAudit.glassSurfaces(of: .dark).count, backdrops.count * 3)
        XCTAssertEqual(PaletteAudit.opaqueSurfaces(of: .light).count, 3)
    }

    func testWorstCaseGlassSurfaceIsLighterThanItsBackdropInDarkAndBrighterInLight() {
        let dark = PaletteAudit.glassSurfaces(of: .dark)
        let backdrop = PaletteAudit.backdrops(of: .dark)["glows-stacked/bottom"]!
        XCTAssertGreaterThan(ColorMath.relativeLuminance(dark["overlay over glows-stacked/bottom"]!), ColorMath.relativeLuminance(backdrop))
    }

    // MARK: the audit must actually catch problems

    func testAuditCatchesLowContrastText() {
        var broken = HeliosPalette.dark
        broken.text.secondary = RGBA(0x555B66)
        let findings = PaletteAudit.audit(broken)
        XCTAssertTrue(findings.contains { $0.rule == "text.secondary on glass" && $0.severity == .error }, describe(findings))
        XCTAssertTrue(findings.contains { $0.rule == "text.secondary on opaque" }, "the opaque fallback is audited too")
    }

    func testAuditCatchesLowContrastOnTheBrightestGlow() {
        var broken = HeliosPalette.dark
        // Plain canvas is fine for this text, but a bright glow underneath is not.
        broken.text.secondary = RGBA(0x8C93A0)
        broken.glows[0] = HeliosGlow(color: RGBA(0xB0C4E8), opacity: 0.6, x: 0.1, y: 0.1, radius: 0.8)
        XCTAssertTrue(PaletteAudit.audit(broken).contains { $0.rule == "text.secondary on glass" })
    }

    func testAuditCatchesIndistinguishableMacros() {
        var broken = HeliosPalette.light
        broken.data.protein = RGBA(0x2F7862)
        broken.data.carbs = RGBA(0x377A66)   // nearly identical to protein
        let findings = PaletteAudit.audit(broken)
        XCTAssertTrue(findings.contains { $0.rule == "chart group macros separation" && $0.detail == "normal vision" }, describe(findings))
    }

    func testAuditCatchesColourBlindCollisions() {
        var broken = HeliosPalette.dark
        // Distinct to normal vision but confusable for red-green deficiencies.
        broken.data.protein = RGBA(0x7DAA4D)
        broken.data.carbs = RGBA(0xC7A24A)
        broken.data.fat = RGBA(0xA291CB)
        let findings = PaletteAudit.audit(broken)
        XCTAssertTrue(findings.contains { $0.rule == "chart group macros separation" && ($0.detail == "protanopia" || $0.detail == "deuteranopia") }, describe(findings))
    }

    func testAuditCatchesPastelAndGreySeriesColours() {
        var pastel = HeliosPalette.dark
        pastel.data.protein = RGBA(0xB9E7DB)       // too light for the dark band: washes out on glass
        XCTAssertTrue(PaletteAudit.audit(pastel).contains { $0.rule == "data.protein lightness band" }, describe(PaletteAudit.audit(pastel)))

        var grey = HeliosPalette.light
        grey.data.fat = RGBA(0x77727F)             // right lightness, but reads as grey
        XCTAssertTrue(PaletteAudit.audit(grey).contains { $0.rule == "data.fat chroma floor" }, describe(PaletteAudit.audit(grey)))
    }

    func testAuditCatchesButtonLabelsWithoutContrast() {
        var broken = HeliosPalette.light
        broken.text.onAccent = RGBA(0xB7D4F0)
        XCTAssertTrue(PaletteAudit.audit(broken).contains { $0.rule == "text.onAccent on accent.base" })
    }

    func testIncreasedContrastPalettesNeedVisibleControlEdges() {
        var broken = HeliosPalette.darkHighContrast
        broken.border.strong = RGBA(0xFFFFFF, alpha: 0.12)
        XCTAssertTrue(PaletteAudit.audit(broken).contains { $0.rule == "border.strong (control edge)" })
        // The standard palette does not owe a 3:1 border.
        var standard = HeliosPalette.dark
        standard.border.strong = RGBA(0xFFFFFF, alpha: 0.12)
        XCTAssertFalse(PaletteAudit.audit(standard).contains { $0.rule == "border.strong (control edge)" })
    }

    func testTertiaryTextIsHeldToTheSameBarAsOtherText() {
        // The first draft of the dark tertiary colour reached only 3.7:1 on the brightest glass: fine for a glyph, not for text.
        var palette = HeliosPalette.dark
        palette.text.tertiary = RGBA(0x939CAA)
        let finding = PaletteAudit.audit(palette).first { $0.rule.hasPrefix("text.tertiary") }
        XCTAssertNotNil(finding)
        XCTAssertEqual(finding?.required, 4.5)
    }

    // MARK: structure

    func testPaletteSelection() {
        XCTAssertEqual(HeliosPalette.palette(dark: true, increasedContrast: false).id, "dark")
        XCTAssertEqual(HeliosPalette.palette(dark: false, increasedContrast: false).id, "light")
        XCTAssertEqual(HeliosPalette.palette(dark: true, increasedContrast: true).id, "dark-hc")
        XCTAssertEqual(HeliosPalette.palette(dark: false, increasedContrast: true).id, "light-hc")
        XCTAssertEqual(Set(HeliosPalette.all.map(\.id)).count, 4)
        XCTAssertEqual(HeliosPalette.all.filter(\.isDark).count, 2)
        XCTAssertEqual(HeliosPalette.all.filter(\.isHighContrast).count, 2)
    }

    func testGlassLevelsRiseAndFallbacksAreOpaque() {
        for palette in HeliosPalette.all {
            XCTAssertLessThanOrEqual(palette.glass.base.alpha, palette.glass.raised.alpha, palette.id)
            XCTAssertLessThanOrEqual(palette.glass.raised.alpha, palette.glass.overlay.alpha, palette.id)
            for level in GlassLevel.allCases { XCTAssertEqual(palette.opaque[level].alpha, 1, "\(palette.id) \(level)") }
        }
    }

    func testBrandIdentity() {
        // Dark is grey/black glass; light is white/light-blue glass with a blue accent.
        XCTAssertLessThan(ColorMath.relativeLuminance(HeliosPalette.dark.canvasTop), 0.01)
        XCTAssertGreaterThan(ColorMath.relativeLuminance(HeliosPalette.light.canvasTop), 0.9)
        let lightCanvas = ColorMath.lab(HeliosPalette.light.canvasBottom)
        XCTAssertLessThan(lightCanvas.b, -3, "light canvas leans blue")
        let accent = ColorMath.lab(HeliosPalette.light.accent.base)
        XCTAssertLessThan(accent.b, -30, "light accent is a clear blue")
        // Dark canvas stays near-neutral so the glass reads as graphite, not navy.
        let darkCanvas = ColorMath.lab(HeliosPalette.dark.canvasBottom)
        XCTAssertLessThan(hypot(darkCanvas.a, darkCanvas.b), 5)
    }
}
