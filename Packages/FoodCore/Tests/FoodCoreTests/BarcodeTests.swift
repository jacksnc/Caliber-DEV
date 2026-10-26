import XCTest
@testable import FoodCore

/// Every code below was computed independently (separate Python implementation of the GS1 mod-10 rule),
/// not by calling the code under test.
final class BarcodeTests: XCTestCase {
    // MARK: check digits

    func testKnownValidCodes() {
        for code in ["036000291452", "4006381333931", "9780306406157", "96385074", "012345678905", "09506000134352"] {
            XCTAssertTrue(GS1.isValid(code), code)
        }
    }

    func testCheckDigitFromBody() {
        XCTAssertEqual(GS1.checkDigit(forBody: "03600029145"), 2)
        XCTAssertEqual(GS1.checkDigit(forBody: "400638133393"), 1)
        XCTAssertEqual(GS1.checkDigit(forBody: "9638507"), 4)
        XCTAssertEqual(GS1.appendingCheckDigit(to: "03600029145"), "036000291452")
    }

    func testRejectsBadCodes() {
        XCTAssertFalse(GS1.isValid("036000291453"))
        XCTAssertFalse(GS1.isValid(""))
        XCTAssertFalse(GS1.isValid("1"))
        XCTAssertFalse(GS1.isValid("03600029145A"))
        XCTAssertFalse(GS1.isValid("٠٣٦٠٠٠٢٩١٤٥٢"), "non-ASCII digits must not validate")
        XCTAssertNil(GS1.checkDigit(forBody: ""))
        XCTAssertNil(GS1.checkDigit(forBody: "12x"))
    }

    // MARK: GTIN forms

    func testUPCAAndEAN13AreTheSameItem() throws {
        let upcA = try XCTUnwrap(GTIN("036000291452"))
        let ean13 = try XCTUnwrap(GTIN("0036000291452"))
        let gtin14 = try XCTUnwrap(GTIN("00036000291452"))
        XCTAssertEqual(upcA, ean13)
        XCTAssertEqual(upcA, gtin14)
        XCTAssertEqual(upcA.digits14, "00036000291452")
        XCTAssertEqual(upcA.upcA, "036000291452")
        XCTAssertEqual(upcA.ean13, "0036000291452")
        XCTAssertNil(upcA.ean8)
        XCTAssertEqual(upcA.shortest, "036000291452")
    }

    func testEAN8PaddingAndForms() throws {
        let ean8 = try XCTUnwrap(GTIN("96385074"))
        XCTAssertEqual(ean8.digits14, "00000096385074")
        XCTAssertEqual(ean8.ean8, "96385074")
        XCTAssertEqual(ean8.ean13, "0000096385074")
        XCTAssertEqual(ean8.shortest, "96385074")
    }

    func testGermanEAN13HasNoUPCA() throws {
        let ean13 = try XCTUnwrap(GTIN("4006381333931"))
        XCTAssertNil(ean13.upcA)
        XCTAssertEqual(ean13.ean13, "4006381333931")
        XCTAssertEqual(ean13.shortest, "4006381333931")
    }

    func testTradeUnitMapsBackToConsumerUnit() throws {
        let tradeUnit = try XCTUnwrap(GTIN("14006381333938"))
        XCTAssertEqual(tradeUnit.packagingLevel, .tradeUnit(indicator: 1))
        XCTAssertNil(tradeUnit.ean13)
        XCTAssertEqual(tradeUnit.consumerUnit, GTIN("4006381333931"))
        XCTAssertEqual(tradeUnit.consumerUnit.packagingLevel, .consumerUnit)
        let item = try XCTUnwrap(GTIN("4006381333931"))
        XCTAssertEqual(item.consumerUnit, item)
    }

    func testRejectsWrongLengthsAndChecks() {
        XCTAssertNil(GTIN("12345"))
        XCTAssertNil(GTIN("0360002914520"))   // 13 digits, wrong check
        XCTAssertNil(GTIN("036000291453"))
        XCTAssertNil(GTIN("123456789012345"))
    }

    func testCodableRoundTripAndValidation() throws {
        let gtin = try XCTUnwrap(GTIN("036000291452"))
        let data = try JSONEncoder().encode([gtin])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "[\"00036000291452\"]")
        XCTAssertEqual(try JSONDecoder().decode([GTIN].self, from: data), [gtin])
        XCTAssertThrowsError(try JSONDecoder().decode([GTIN].self, from: Data("[\"00036000291453\"]".utf8)))
    }

    // MARK: classification

    func testKindClassification() throws {
        let cases: [(String, BarcodeKind)] = [
            ("036000291452", .consumerProduct),
            ("4006381333931", .consumerProduct),
            ("96385074", .consumerProduct),
            ("212345001233", .variableMeasure),   // UPC number system 2
            ("2001234500128", .variableMeasure),  // EAN prefix 200-299
            ("312345678906", .drug),              // UPC number system 3 (NDC)
            ("412345678903", .inStore),           // UPC number system 4
            ("512345678900", .coupon),            // UPC number system 5
            ("9780306406157", .book),
            ("9771234567898", .periodical),
            ("9801234567892", .refundReceipt),
            ("9811234567891", .coupon),
            ("9912345678909", .coupon),
        ]
        for (code, kind) in cases {
            XCTAssertEqual(try XCTUnwrap(GTIN(code)).kind, kind, code)
        }
        XCTAssertTrue(BarcodeKind.consumerProduct.isLookupWorthy)
        XCTAssertFalse(BarcodeKind.variableMeasure.isLookupWorthy)
    }

    // MARK: UPC-E

    func testWikipediaUPCEExample() {
        XCTAssertEqual(GS1.expandUPCE("04252614"), "042100005264")
        XCTAssertEqual(GS1.compressUPCA("042100005264"), "04252614")
    }

    func testAllFourZeroSuppressionPatterns() {
        // (UPC-A, UPC-E) pairs: last UPC-E digit before the check selects the pattern.
        let pairs = [
            ("012100003454", "01234514"),   // 0-2: manufacturer ends 100, product 00345
            ("012300000451", "01234531"),   // 3:   manufacturer ends 00,  product 00045
            ("012340000053", "01234543"),   // 4:   manufacturer ends 0,   product 00005
            ("012345000065", "01234565"),   // 5-9: five-digit manufacturer, product 00006
            ("123200007898", "12378928"),   // number system 1, pattern 0-2 with digit 2
        ]
        for (upcA, upcE) in pairs {
            XCTAssertEqual(GS1.expandUPCE(upcE), upcA, "expand \(upcE)")
            XCTAssertEqual(GS1.compressUPCA(upcA), upcE, "compress \(upcA)")
        }
    }

    func testUPCERejections() {
        XCTAssertNil(GS1.expandUPCE("04252615"), "bad check digit")
        XCTAssertNil(GS1.expandUPCE("24252614"), "number system must be 0 or 1")
        XCTAssertNil(GS1.expandUPCE("0425261"), "7 digits")
        XCTAssertNil(GS1.expandUPCE("0425261x"))
        XCTAssertNil(GS1.compressUPCA("212345000014"), "number system 2 cannot be compressed")
        XCTAssertNil(GS1.compressUPCA("012345000010"), "five-digit manufacturer with product 00001 has no UPC-E")
        XCTAssertNil(GS1.compressUPCA("042100005265"), "invalid check digit")
    }

    func testExpandThenCompressIsIdentityOnASample() throws {
        var checked = 0
        var core = 0
        while core < 1_000_000 {
            for numberSystem in [0, 1] {
                let six = String(format: "%06d", core)
                let withoutCheck = "\(numberSystem)\(six)"
                // Derive the UPC-E check digit through the expansion so this test does not assume it.
                var found: String?
                for check in 0...9 {
                    let candidate = withoutCheck + String(check)
                    if GS1.expandUPCE(candidate) != nil { found = candidate; break }
                }
                let upcE = try XCTUnwrap(found, withoutCheck)
                let upcA = try XCTUnwrap(GS1.expandUPCE(upcE))
                XCTAssertEqual(upcA.count, 12)
                XCTAssertTrue(GS1.isValid(upcA))
                let recompressed = try XCTUnwrap(GS1.compressUPCA(upcA), "UPC-A \(upcA) from \(upcE) must be compressible")
                XCTAssertEqual(GS1.expandUPCE(recompressed), upcA, "\(upcE) -> \(upcA) -> \(recompressed)")
                checked += 1
            }
            core += 4_391
        }
        XCTAssertGreaterThan(checked, 400)
    }

    // MARK: normalizer

    func testPlainUPCA() throws {
        let result = BarcodeNormalizer.normalize("036000291452")
        guard case let .valid(candidates) = result else { return XCTFail("expected valid, got \(result)") }
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].format, .upcA)
        XCTAssertEqual(candidates[0].gtin.digits14, "00036000291452")
        XCTAssertEqual(candidates[0].original, "036000291452")
    }

    func testEAN13FromUPCAWithLeadingZeroMatchesUPCA() {
        let a = BarcodeNormalizer.normalize("036000291452", symbology: .upcA).candidates.first?.gtin
        let b = BarcodeNormalizer.normalize("0036000291452", symbology: .ean13).candidates.first?.gtin
        XCTAssertNotNil(a)
        XCTAssertEqual(a, b, "Vision/AVFoundation report UPC-A as EAN-13 with a leading zero")
    }

    func testTolerantOfSpacingAndHyphens() {
        let result = BarcodeNormalizer.normalize("  0 36000 29145 2\n")
        XCTAssertEqual(result.candidates.first?.gtin.digits14, "00036000291452")
        XCTAssertEqual(BarcodeNormalizer.normalize("4-006381-333931").candidates.first?.format, .ean13)
    }

    func testGTIN14Input() {
        let result = BarcodeNormalizer.normalize("14006381333938", symbology: .itf14)
        XCTAssertEqual(result.candidates.first?.format, .gtin14)
        XCTAssertEqual(result.candidates.first?.gtin.consumerUnit.ean13, "4006381333931")
    }

    func testBadCheckDigitReportsExpectedAndSuggestions() {
        let result = BarcodeNormalizer.normalize("036000291453")
        guard case let .invalid(.badCheckDigit(expected, suggestions)) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(expected, 2)
        XCTAssertEqual(suggestions.first, "036000291452")
    }

    func testSuggestionsIncludeAdjacentSwap() {
        // 036000291452 with the 9 and 1 swapped: 036000219452.
        let suggestions = BarcodeNormalizer.suggestions(forInvalid: "036000219452")
        XCTAssertTrue(suggestions.contains("036000291452"), "\(suggestions)")
        XCTAssertTrue(suggestions.allSatisfy(GS1.isValid))
        XCTAssertEqual(BarcodeNormalizer.suggestions(forInvalid: "036000291452"), [], "valid codes need no suggestions")
    }

    func testInvalidShapes() {
        XCTAssertEqual(BarcodeNormalizer.normalize(""), .invalid(.empty))
        XCTAssertEqual(BarcodeNormalizer.normalize("   "), .invalid(.empty))
        XCTAssertEqual(BarcodeNormalizer.normalize("12345"), .invalid(.unsupportedLength(5)))
        XCTAssertEqual(BarcodeNormalizer.normalize("1234567890123456789"), .invalid(.unsupportedLength(19)))
        XCTAssertEqual(BarcodeNormalizer.normalize("03600029145A"), .invalid(.containsNonDigits))
        XCTAssertEqual(BarcodeNormalizer.normalize("hello"), .invalid(.containsNonDigits))
    }

    func testEightDigitCodeThatCanOnlyBeEAN8() {
        let result = BarcodeNormalizer.normalize("96385074")
        XCTAssertEqual(result.candidates.map(\.format), [.ean8])
    }

    func testEightDigitCodeThatCanOnlyBeUPCE() {
        // 04252614 fails the EAN-8 check (it would need 0) but is a valid UPC-E.
        let result = BarcodeNormalizer.normalize("04252614")
        XCTAssertEqual(result.candidates.map(\.format), [.upcE])
        XCTAssertEqual(result.candidates.first?.gtin.upcA, "042100005264")
        XCTAssertEqual(result.candidates.first?.original, "04252614")
    }

    func testAmbiguousEightDigitCodeReturnsBothReadings() {
        // 01000146 passes the EAN-8 check and is also a valid UPC-E (expands to 010000000016).
        let both = BarcodeNormalizer.normalize("01000146")
        XCTAssertEqual(both.candidates.map(\.format), [.ean8, .upcE])
        XCTAssertNotEqual(both.candidates[0].gtin, both.candidates[1].gtin)
        XCTAssertEqual(both.candidates[1].gtin.upcA, "010000000016")

        XCTAssertEqual(BarcodeNormalizer.normalize("01000146", preferUPCE: true).candidates.map(\.format), [.upcE, .ean8])
        XCTAssertEqual(BarcodeNormalizer.normalize("01000146", symbology: .upcE).candidates.map(\.format), [.upcE])
        XCTAssertEqual(BarcodeNormalizer.normalize("01000146", symbology: .ean8).candidates.map(\.format), [.ean8])
    }

    func testRealisticUPCEIsAlsoAValidEAN8WithoutASymbology() throws {
        // 01234565 is the UPC-E of 012345000065. For the five-digit-manufacturer pattern the UPC-E and EAN-8 check-digit
        // weights are identical, so more than half of all UPC-E codes are ambiguous: the symbology must be passed.
        let unknown = BarcodeNormalizer.normalize("01234565")
        XCTAssertEqual(unknown.candidates.map(\.format), [.ean8, .upcE])
        XCTAssertEqual(unknown.candidates[1].gtin.upcA, "012345000065")

        let scanned = BarcodeNormalizer.normalize("01234565", symbology: .upcE)
        XCTAssertEqual(scanned.candidates.map(\.format), [.upcE])
        XCTAssertEqual(scanned.candidates.first?.gtin, GTIN("012345000065"))
    }

    func testEightDigitCodeInvalidForBothReadings() {
        guard case let .invalid(.badCheckDigit(expected, _)) = BarcodeNormalizer.normalize("96385075") else {
            return XCTFail("expected bad check digit")
        }
        XCTAssertEqual(expected, 4)
    }

    func testSymbologyIdentifierPrefixIsStripped() {
        XCTAssertEqual(BarcodeNormalizer.normalize("]E0036000291452").candidates.first?.gtin.digits14, "00036000291452")
    }

    // MARK: symbology mapping

    func testSymbologyIdentifiers() {
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyEAN13"), .ean13)
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyUPCE"), .upcE)
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyEAN8"), .ean8)
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyITF14"), .itf14)
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyGS1DataBarExpanded"), .gs1DataBarExpanded)
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyQR"), .qr)
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyDataMatrix"), .dataMatrix)
        XCTAssertEqual(BarcodeSymbology(identifier: "VNBarcodeSymbologyCode128"), .code128)
        XCTAssertEqual(BarcodeSymbology(identifier: "org.gs1.EAN-13"), .ean13)
        XCTAssertEqual(BarcodeSymbology(identifier: "something-new"), .other)
    }
}
