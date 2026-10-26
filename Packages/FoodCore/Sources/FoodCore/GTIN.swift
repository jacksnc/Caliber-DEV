import Foundation

/// What a barcode is for, derived from its GS1 prefix. Only `consumerProduct` is worth a product-database lookup.
public enum BarcodeKind: String, Codable, Sendable, CaseIterable {
    /// Ordinary packaged product (UPC number systems 0, 1, 6-9 and the national EAN prefixes).
    case consumerProduct
    /// Retailer-assigned code for random-weight items such as deli meat or produce (UPC number system 2, EAN 20-29).
    /// Price or weight is embedded, so no global database can know it.
    case variableMeasure
    /// Restricted-distribution code used inside one retailer (loyalty cards, in-store labels).
    case inStore
    case coupon
    case book
    case periodical
    case refundReceipt
    /// Drug or health product coded with an NDC / NHRIC (UPC number system 3). Not a food.
    case drug

    public var isLookupWorthy: Bool { self == .consumerProduct }
}

/// Where a GTIN sits in the packaging hierarchy.
public enum PackagingLevel: Equatable, Sendable {
    /// The unit a shopper buys (GTIN-8/12/13, or a GTIN-14 whose indicator digit is 0).
    case consumerUnit
    /// A case or inner pack. Indicator digits 1-8 are packaging levels; 9 marks a variable-measure trade item.
    case tradeUnit(indicator: Int)
}

/// A validated Global Trade Item Number held in its canonical 14-digit, zero-padded form.
/// UPC-A, EAN-13, EAN-8 and GTIN-14 spellings of the same item all compare equal.
public struct GTIN: Hashable, Sendable, Codable, CustomStringConvertible {
    public let digits14: String

    /// Accepts 8, 12, 13 or 14 digits with a correct check digit.
    public init?(_ code: String) {
        let length = code.utf8.count
        guard [8, 12, 13, 14].contains(length), GS1.isValid(code) else { return nil }
        digits14 = String(repeating: "0", count: 14 - length) + code
    }

    /// Expands a validated UPC-E (8 digits) to its UPC-A and wraps it.
    public init?(upcE: String) {
        guard let upcA = GS1.expandUPCE(upcE) else { return nil }
        self.init(upcA)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let gtin = GTIN(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a valid GTIN: \(text)")
        }
        self = gtin
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(digits14)
    }

    public var description: String { digits14 }

    private var digits: [Int] { digits14.utf8.map { Int($0) - 48 } }

    public var indicator: Int { digits[0] }

    public var packagingLevel: PackagingLevel {
        indicator == 0 ? .consumerUnit : .tradeUnit(indicator: indicator)
    }

    /// The consumer-unit GTIN for a case or inner pack: drop the indicator digit and recompute the check digit.
    /// Consumer units return themselves.
    public var consumerUnit: GTIN {
        guard indicator != 0 else { return self }
        let base = String(digits14.dropFirst().prefix(12))
        let check = GS1.checkDigit(forBody: base) ?? 0
        return GTIN("0" + base + String(check)) ?? self
    }

    /// 13-digit form; nil for trade units, which cannot be expressed as an EAN-13.
    public var ean13: String? {
        indicator == 0 ? String(digits14.dropFirst()) : nil
    }

    /// 12-digit UPC-A form, when the code has one.
    public var upcA: String? {
        digits14.hasPrefix("00") ? String(digits14.dropFirst(2)) : nil
    }

    /// 8-digit EAN-8 form, when the code has one.
    public var ean8: String? {
        digits14.hasPrefix("000000") ? String(digits14.dropFirst(6)) : nil
    }

    /// Zero-suppressed UPC-E form, when the UPC-A allows it.
    public var upcE: String? {
        upcA.flatMap(GS1.compressUPCA)
    }

    /// Digits with leading zeros trimmed down to the shortest standard length (8, 12, 13 or 14).
    public var shortest: String {
        if let ean8 { return ean8 }
        if let upcA { return upcA }
        if let ean13 { return ean13 }
        return digits14
    }

    /// First three digits of the embedded GTIN-13, the part GS1 prefixes are defined on.
    private var prefix3: Int {
        let start = digits14.index(digits14.startIndex, offsetBy: 1)
        let end = digits14.index(start, offsetBy: 3)
        return Int(digits14[start..<end]) ?? 0
    }

    public var kind: BarcodeKind {
        switch prefix3 {
        case 20...29, 200...299: return .variableMeasure
        case 30...39: return .drug
        case 40...49: return .inStore
        case 50...59, 981...984, 990...999: return .coupon
        case 977: return .periodical
        case 978, 979: return .book
        case 980: return .refundReceipt
        default: return .consumerProduct
        }
    }
}
