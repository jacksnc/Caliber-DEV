import XCTest
@testable import HeliosDesign

final class TokensTests: XCTestCase {
    func testMetrics() {
        XCTAssertEqual(HeliosTokens.minimumTapTarget, 44, "Apple's minimum touch target")
        XCTAssertEqual(HeliosTokens.spacing, HeliosTokens.spacing.sorted())
        XCTAssertEqual(HeliosTokens.spacing.first, 4)
        let radius = HeliosTokens.radius
        XCTAssertTrue(radius.chip < radius.button && radius.button < radius.tile && radius.tile < radius.card && radius.card < radius.sheet)
        XCTAssertGreaterThan(HeliosTokens.glass.blur, 0)
        XCTAssertTrue(HeliosTokens.motion.fast < HeliosTokens.motion.base && HeliosTokens.motion.base < HeliosTokens.motion.slow)
    }

    func testTypographyIsExpressedOnlyThroughDynamicTypeStyles() {
        XCTAssertGreaterThanOrEqual(HeliosTypeRole.allCases.count, 10)
        for role in HeliosTypeRole.allCases {
            // `spec.style` is a DynamicTypeStyle: there is no way to state a point size, so text always scales.
            XCTAssertTrue(DynamicTypeStyle.allCases.contains(role.spec.style), "\(role)")
        }
        XCTAssertEqual(HeliosTypeRole.hero.spec.style, .largeTitle)
        XCTAssertTrue(HeliosTypeRole.hero.spec.monospacedDigit, "numbers must not jitter as they change")
        XCTAssertTrue(HeliosTypeRole.metricValue.spec.monospacedDigit)
        XCTAssertEqual(HeliosTypeRole.body.spec.design, .default)
        XCTAssertEqual(HeliosTypeRole.hero.spec.design, .rounded)
    }

    func testChartGroupsReferenceRealColoursAndAreSeparated() {
        XCTAssertEqual(HeliosTokens.chartGroups.map(\.name), ["macros", "domains"])
        for group in HeliosTokens.chartGroups {
            for member in group.members { XCTAssertNotNil(HeliosPalette.dark.data.color(named: member), member) }
        }
        XCTAssertEqual(HeliosTokens.chartGroups[0].members, ["protein", "carbs", "fat"])
        XCTAssertGreaterThanOrEqual(HeliosTokens.chartGroups[0].minDeltaE, 28)
        XCTAssertNil(HeliosPalette.dark.data.color(named: "nonsense"))
        XCTAssertEqual(DataColors.names.count, 8)
    }

    func testMacroColoursKeepTheirIdentityAcrossThemes() {
        // The same hue family in every theme, so a user who learned "teal is protein" never has to relearn it.
        func hue(_ color: RGBA) -> Double {
            let lab = ColorMath.lab(color)
            var degrees = atan2(lab.b, lab.a) * 180 / .pi
            if degrees < 0 { degrees += 360 }
            return degrees
        }
        func circularDistance(_ a: Double, _ b: Double) -> Double {
            let d = abs(a - b).truncatingRemainder(dividingBy: 360)
            return min(d, 360 - d)
        }
        for name in ["protein", "carbs", "fat", "training", "energy"] {
            let dark = hue(HeliosPalette.dark.data.color(named: name)!)
            let light = hue(HeliosPalette.light.data.color(named: name)!)
            XCTAssertLessThan(circularDistance(dark, light), 45, "\(name): dark \(dark), light \(light)")
        }
    }

    func testHighContrastVariantsOnlyChangeWhatTheyShould() {
        XCTAssertEqual(HeliosPalette.darkHighContrast.data, HeliosPalette.dark.data)
        XCTAssertEqual(HeliosPalette.lightHighContrast.accent, HeliosPalette.light.accent)
        XCTAssertNotEqual(HeliosPalette.darkHighContrast.text.secondary, HeliosPalette.dark.text.secondary)
        XCTAssertGreaterThan(HeliosPalette.darkHighContrast.border.strong.alpha, HeliosPalette.dark.border.strong.alpha)
        XCTAssertEqual(HeliosPalette.darkHighContrast.canvasTop, HeliosPalette.dark.canvasTop)
    }
}
