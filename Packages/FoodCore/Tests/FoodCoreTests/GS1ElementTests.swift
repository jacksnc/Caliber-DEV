import XCTest
@testable import FoodCore

final class GS1ElementTests: XCTestCase {
    private func parsed(_ raw: String, file: StaticString = #filePath, line: UInt = #line) throws -> GS1ElementString {
        switch GS1ElementString.parse(raw) {
        case let .success(value): return value
        case let .failure(error):
            XCTFail("parse failed: \(error)", file: file, line: line)
            throw error
        }
    }

    func testParenthesizedForm() throws {
        let s = try parsed("(01)09506000134352(17)261231(10)LOT7")
        XCTAssertEqual(s.elements.map(\.ai), ["01", "17", "10"])
        XCTAssertEqual(s.gtin?.digits14, "09506000134352")
        XCTAssertEqual(s.lot, "LOT7")
        XCTAssertEqual(s.value(of: "17"), "261231")
    }

    func testRawFormWithFixedLengthFieldsOnly() throws {
        let s = try parsed("01095060001343521726123110LOT7")
        XCTAssertEqual(s.gtin?.digits14, "09506000134352")
        XCTAssertEqual(s.expiry(referenceYear: 2026), GS1Date(year: 2026, month: 12, day: 31))
        XCTAssertEqual(s.lot, "LOT7")
    }

    func testVariableLengthFieldEndsAtGroupSeparator() throws {
        let s = try parsed("0109506000134352" + "10LOT7" + "\u{1D}" + "17261231")
        XCTAssertEqual(s.lot, "LOT7")
        XCTAssertEqual(s.value(of: "17"), "261231")
        XCTAssertEqual(s.elements.count, 3)
    }

    func testSymbologyIdentifierIsIgnored() throws {
        let s = try parsed("]d2" + "0109506000134352" + "21SER99")
        XCTAssertEqual(s.serial, "SER99")
    }

    func testDecimalWeightsAndCounts() throws {
        XCTAssertEqual(try parsed("(01)09506000134352(3103)001500").netWeightKilograms ?? 0, 1.5, accuracy: 1e-12)
        XCTAssertEqual(try parsed("(01)09506000134352(3202)002500").netWeightPounds ?? 0, 25.0, accuracy: 1e-12)
        XCTAssertEqual(try parsed("(01)09506000134352(30)12").itemCount, 12)
        XCTAssertNil(try parsed("(01)09506000134352").netWeightKilograms)
    }

    func testContentGTINAI02() throws {
        let s = try parsed("(02)09506000134352(37)24")
        XCTAssertEqual(s.gtin?.digits14, "09506000134352")
        XCTAssertEqual(s.itemCount, 24)
    }

    func testDateWindowAndEndOfMonth() {
        XCTAssertEqual(GS1Date.parse("261231", referenceYear: 2026), GS1Date(year: 2026, month: 12, day: 31))
        XCTAssertEqual(GS1Date.parse("760101", referenceYear: 2026)?.year, 1976)
        XCTAssertEqual(GS1Date.parse("750101", referenceYear: 2026)?.year, 2075)
        XCTAssertEqual(GS1Date.parse("990101", referenceYear: 2026)?.year, 2099 - 100)
        XCTAssertEqual(GS1Date.parse("260200", referenceYear: 2026)?.resolvedDay, 28)
        XCTAssertEqual(GS1Date.parse("280200", referenceYear: 2026)?.resolvedDay, 29, "2028 is a leap year")
        XCTAssertEqual(GS1Date.parse("000200", referenceYear: 2026)?.resolvedDay, 29, "2000 was a leap year")
        XCTAssertEqual(GS1Date.parse("260200", referenceYear: 2026)?.day, nil)
        XCTAssertNil(GS1Date.parse("261301", referenceYear: 2026), "month 13")
        XCTAssertNil(GS1Date.parse("260231", referenceYear: 2026), "31 February")
        XCTAssertNil(GS1Date.parse("2612", referenceYear: 2026))
    }

    func testParseErrors() {
        XCTAssertEqual(GS1ElementString.parse(""), .failure(.empty))
        XCTAssertEqual(GS1ElementString.parse("(01)0950600013"), .failure(.truncated(ai: "01")))
        XCTAssertEqual(GS1ElementString.parse("(01)09506000134352(88)zz"), .failure(.unknownIdentifier("88")))
        XCTAssertEqual(GS1ElementString.parse("(01"), .failure(.malformedParentheses))
        XCTAssertEqual(GS1ElementString.parse("(10)" + String(repeating: "A", count: 21)), .failure(.tooLong(ai: "10")))
        XCTAssertEqual(GS1ElementString.parse("(17)26AB31"), .failure(.invalidCharacters(ai: "17")))
        XCTAssertEqual(GS1ElementString.parse("(10)"), .failure(.truncated(ai: "10")))
        guard case .failure(.unknownIdentifier) = GS1ElementString.parse("8506000134352") else { return XCTFail("85 is not an identifier we know") }
        XCTAssertNotNil(try? GS1ElementString.parse("9506000134352").get(), "AI 95 is a valid company-internal identifier")
        XCTAssertEqual(GS1ElementString.parse("01095060"), .failure(.truncated(ai: "01")))
    }

    func testInvalidCheckDigitInsideElementStringYieldsNoGTIN() throws {
        let s = try parsed("(01)09506000134353")
        XCTAssertNil(s.gtin)
    }

    // MARK: Digital Link

    func testDigitalLinkWithQueryAndPath() throws {
        let s = try XCTUnwrap(GS1DigitalLink.parse("https://id.gs1.org/01/09506000134352/10/LOT7?17=261231"))
        XCTAssertEqual(s.gtin?.digits14, "09506000134352")
        XCTAssertEqual(s.lot, "LOT7")
        XCTAssertEqual(s.expiry(referenceYear: 2026)?.month, 12)
    }

    func testDigitalLinkWithBrandPathPrefixAndEncoding() throws {
        let s = try XCTUnwrap(GS1DigitalLink.parse("https://brand.example/p/q/01/09506000134352/21/AB%2F12"))
        XCTAssertEqual(s.serial, "AB/12")
    }

    func testDigitalLinkIgnoresUnknownKeys() throws {
        let s = try XCTUnwrap(GS1DigitalLink.parse("https://id.gs1.org/01/09506000134352?utm=abc&17=261231"))
        XCTAssertEqual(s.elements.map(\.ai), ["01", "17"])
    }

    func testDigitalLinkWithoutGTINIsRejected() {
        XCTAssertNil(GS1DigitalLink.parse("https://example.com/item/42"))
        XCTAssertNil(GS1DigitalLink.parse("https://id.gs1.org/01/09506000134353"), "bad check digit")
    }

    // MARK: end to end through the normalizer

    func testInterpretGS1ElementStringPayload() {
        let result = BarcodeNormalizer.interpret("]d2" + "0109506000134352" + "10LOT7", symbology: .dataMatrix)
        XCTAssertEqual(result.normalization.candidates.first?.format, .gs1ElementString)
        XCTAssertEqual(result.normalization.candidates.first?.gtin.digits14, "09506000134352")
        XCTAssertEqual(result.gs1?.lot, "LOT7")
    }

    func testInterpretBareSixteenDigitElementString() {
        let result = BarcodeNormalizer.interpret("0109506000134352")
        XCTAssertEqual(result.normalization.candidates.first?.gtin.digits14, "09506000134352")
    }

    func testInterpretDigitalLink() {
        let result = BarcodeNormalizer.interpret("https://id.gs1.org/01/09506000134352/10/LOT7", symbology: .qr)
        XCTAssertEqual(result.normalization.candidates.first?.format, .gs1DigitalLink)
        XCTAssertEqual(result.gs1?.lot, "LOT7")
    }

    func testInterpretNonProductPayloads() {
        XCTAssertEqual(BarcodeNormalizer.normalize("https://example.com/menu"), .invalid(.notAProductCode))
        XCTAssertEqual(BarcodeNormalizer.normalize("(00)123456789012345675"), .invalid(.notAProductCode), "SSCC carries no GTIN")
        XCTAssertEqual(BarcodeNormalizer.normalize("(88)abc"), .invalid(.notAProductCode))
    }

    func testPlainTwelveDigitCodeStartingWith01IsNotMistakenForElementString() {
        // 12 digits: far too short for an AI 01 element string, so it is read as UPC-A.
        XCTAssertEqual(BarcodeNormalizer.normalize("012345678905").candidates.first?.format, .upcA)
    }
}
