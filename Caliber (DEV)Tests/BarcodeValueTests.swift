import XCTest

@testable import Caliber__DEV_

nonisolated final class BarcodeValueTests: XCTestCase {
  func testValidGTINLengths() throws {
    XCTAssertEqual(try BarcodeValue.normalize("96385074"), "96385074")
    XCTAssertEqual(try BarcodeValue.normalize("036000291452"), "036000291452")
    XCTAssertEqual(try BarcodeValue.normalize("4006381333931"), "4006381333931")
    XCTAssertEqual(try BarcodeValue.normalize("10012345000017"), "10012345000017")
  }

  func testUPCAAndCameraEAN13AreEquivalent() throws {
    let upc = "036000291452"
    XCTAssertEqual(try BarcodeValue.normalize("0036000291452"), upc)
    XCTAssertEqual(try BarcodeValue.normalize("00036000291452"), upc)
    XCTAssertEqual(try BarcodeValue.gtin14(upc), "00036000291452")
    XCTAssertEqual(try BarcodeValue.gtin14("0036000291452"), try BarcodeValue.gtin14(upc))
  }

  func testLeadingZeroAndPackagingIndicatorKeepTheirMeaning() throws {
    XCTAssertEqual(try BarcodeValue.normalize("012345678905"), "012345678905")
    XCTAssertEqual(try BarcodeValue.normalize("10012345000017"), "10012345000017")
    XCTAssertEqual(try BarcodeValue.gtin14("96385074"), "00000096385074")
  }

  func testOuterWhitespaceIsTrimmedButInteriorCharactersAreNotDiscarded() throws {
    XCTAssertEqual(try BarcodeValue.normalize(" \n036000291452\t"), "036000291452")
    for code in ["0 36000 29145 2", "036000-291452"] {
      XCTAssertThrowsError(try BarcodeValue.normalize(code)) { error in
        XCTAssertEqual(error as? BarcodeValue.ValidationError, .invalidCharacters)
      }
    }
  }

  func testInvalidChecksumForEverySupportedLength() {
    for code in ["96385075", "036000291453", "4006381333932", "10012345000018"] {
      XCTAssertThrowsError(try BarcodeValue.normalize(code)) { error in
        XCTAssertEqual(error as? BarcodeValue.ValidationError, .invalidChecksum)
      }
    }
  }

  func testNonASCIIDigitsURLsSignsAndDecimalsAreRejected() {
    for code in [
      "０３６０００２９１４５２", "٠٣٦٠٠٠٢٩١٤٥٢", "https://example.com/036000291452", "+036000291452",
      "03600029145.2", "03600029145A",
    ] {
      XCTAssertThrowsError(try BarcodeValue.normalize(code)) { error in
        XCTAssertEqual(error as? BarcodeValue.ValidationError, .invalidCharacters)
      }
    }
  }

  func testEmptyAndUnsupportedLengthsCannotBecomeAnotherCode() {
    for code in ["", "  \n"] {
      XCTAssertThrowsError(try BarcodeValue.normalize(code)) { error in
        XCTAssertEqual(error as? BarcodeValue.ValidationError, .empty)
      }
    }
    for code in ["123456", "1234567", "123456789", "12345678901", "123456789012345"] {
      XCTAssertThrowsError(try BarcodeValue.normalize(code)) { error in
        XCTAssertEqual(error as? BarcodeValue.ValidationError, .unsupportedLength)
      }
    }
  }

  func testEverySingleDigitChangeIsDetected() {
    for original in ["96385074", "036000291452", "4006381333931", "10012345000017"] {
      let digits = Array(original)
      for index in digits.indices {
        var changed = digits
        let value = digits[index].wholeNumberValue!
        changed[index] = Character(String((value + 1) % 10))
        XCTAssertFalse(
          BarcodeValue.isValid(String(changed)), "Missed digit change at \(index) in \(original)")
      }
    }
  }
}
