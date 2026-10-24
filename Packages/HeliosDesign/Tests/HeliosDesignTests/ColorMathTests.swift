import XCTest
@testable import HeliosDesign

final class ColorMathTests: XCTestCase {
    private let white = RGBA(0xFFFFFF)
    private let black = RGBA(0x000000)

    func testHexRoundTripAndComponents() {
        let color = RGBA(0x8AD0FF)
        XCTAssertEqual(color.hex, "#8AD0FF")
        XCTAssertEqual(color.red, 138.0 / 255, accuracy: 1e-12)
        XCTAssertEqual(color.alpha, 1)
        XCTAssertEqual(RGBA(0xFFFFFF, alpha: 0.5).alpha, 0.5)
        XCTAssertEqual(RGBA(red: 2, green: -1, blue: 0.5).hex, "#FF0080", "out-of-range channels are clamped for display")
    }

    func testContrastReferenceValues() {
        XCTAssertEqual(ColorMath.contrastRatio(white, black), 21, accuracy: 1e-9)
        XCTAssertEqual(ColorMath.contrastRatio(white, white), 1, accuracy: 1e-12)
        // #767676 is the lightest grey that reaches 4.5:1 on white, the classic WCAG boundary.
        XCTAssertEqual(ColorMath.contrastRatio(RGBA(0x767676), white), 4.54, accuracy: 0.01)
        XCTAssertLessThan(ColorMath.contrastRatio(RGBA(0x777777), white), 4.5 + 0.05)
        XCTAssertEqual(ColorMath.contrastRatio(black, white), ColorMath.contrastRatio(white, black), accuracy: 1e-12, "symmetric")
    }

    func testRelativeLuminance() {
        XCTAssertEqual(ColorMath.relativeLuminance(white), 1, accuracy: 1e-12)
        XCTAssertEqual(ColorMath.relativeLuminance(black), 0, accuracy: 1e-12)
        XCTAssertEqual(ColorMath.relativeLuminance(RGBA(0xFF0000)), 0.2126, accuracy: 1e-9)
        XCTAssertEqual(ColorMath.relativeLuminance(RGBA(0x00FF00)), 0.7152, accuracy: 1e-9)
        XCTAssertEqual(ColorMath.relativeLuminance(RGBA(0x0000FF)), 0.0722, accuracy: 1e-9)
    }

    func testCompositing() {
        let half = RGBA(0xFFFFFF, alpha: 0.5).composited(over: black)
        XCTAssertEqual(half.red, 0.5, accuracy: 1e-12)
        XCTAssertEqual(half.alpha, 1, accuracy: 1e-12)
        XCTAssertEqual(RGBA(0xFF0000, alpha: 1).composited(over: white), RGBA(0xFF0000))
        XCTAssertEqual(RGBA(0xFF0000, alpha: 0).composited(over: white).hex, "#FFFFFF")
        // 5% white over #15171C, computed by hand: 0.05 * 255 + 0.95 * (21, 23, 28)
        let surface = RGBA(0xFFFFFF, alpha: 0.05).composited(over: RGBA(0x15171C))
        XCTAssertEqual(surface.red * 255, 0.05 * 255 + 0.95 * 21, accuracy: 1e-9)
        XCTAssertEqual(surface.blue * 255, 0.05 * 255 + 0.95 * 28, accuracy: 1e-9)
        // Translucent over translucent keeps accumulating alpha.
        let stacked = RGBA(0xFFFFFF, alpha: 0.5).composited(over: RGBA(0x000000, alpha: 0.5))
        XCTAssertEqual(stacked.alpha, 0.75, accuracy: 1e-12)
        XCTAssertEqual(RGBA(0x000000, alpha: 0).composited(over: RGBA(0x000000, alpha: 0)).alpha, 0)
    }

    func testMixing() {
        XCTAssertEqual(black.mixed(with: white, amount: 0.5).red, 0.5, accuracy: 1e-12)
        XCTAssertEqual(black.mixed(with: white, amount: -3), black)
        XCTAssertEqual(black.mixed(with: white, amount: 7), white)
    }

    func testLabReferenceValues() {
        let whiteLab = ColorMath.lab(white)
        XCTAssertEqual(whiteLab.lightness, 100, accuracy: 0.01)
        XCTAssertEqual(whiteLab.a, 0, accuracy: 0.05)
        XCTAssertEqual(whiteLab.b, 0, accuracy: 0.05)
        // sRGB red in Lab (D65): L 53.24, a 80.09, b 67.20
        let redLab = ColorMath.lab(RGBA(0xFF0000))
        XCTAssertEqual(redLab.lightness, 53.24, accuracy: 0.05)
        XCTAssertEqual(redLab.a, 80.09, accuracy: 0.1)
        XCTAssertEqual(redLab.b, 67.20, accuracy: 0.1)
        XCTAssertEqual(ColorMath.deltaE76(white, black), 100, accuracy: 0.01)
        XCTAssertEqual(ColorMath.deltaE76(RGBA(0xFF0000), RGBA(0xFF0000)), 0)
    }

    func testColourVisionSimulationKeepsGreysAndSeparatesWhatItShould() {
        for deficiency in ColorMath.ColorVisionDeficiency.allCases {
            let grey = deficiency.simulate(RGBA(0x808080))
            XCTAssertEqual(grey.red, 0.5019, accuracy: 0.01, "\(deficiency) preserves neutral greys")
            XCTAssertEqual(grey.green, 0.5019, accuracy: 0.01)
            XCTAssertEqual(grey.blue, 0.5019, accuracy: 0.01)
        }
        // Red and green are hard to tell apart without red/green vision, easy with normal vision.
        let red = RGBA(0xE0402F), green = RGBA(0x2FA04F)
        let normal = ColorMath.deltaE76(red, green)
        let deutan = ColorMath.deltaE76(ColorMath.ColorVisionDeficiency.deuteranopia.simulate(red), ColorMath.ColorVisionDeficiency.deuteranopia.simulate(green))
        XCTAssertGreaterThan(normal, 60)
        XCTAssertLessThan(deutan, normal * 0.5)
    }

    func testMinimumSeparation() {
        XCTAssertEqual(ColorMath.minimumSeparation([white, black]), 100, accuracy: 0.01)
        XCTAssertEqual(ColorMath.minimumSeparation([white]), .infinity)
        XCTAssertEqual(ColorMath.minimumSeparation([RGBA(0x808080), RGBA(0x808080), black]), 0, accuracy: 1e-9)
    }
}
