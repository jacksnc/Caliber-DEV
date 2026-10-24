import Foundation

/// Symbology reported by the camera framework. UPC-A usually arrives as an EAN-13 with a leading zero,
/// so the normalizer never relies on the symbology to tell the two apart.
public enum BarcodeSymbology: String, Codable, Sendable, CaseIterable {
    case ean13, ean8, upcA, upcE, itf14, interleaved2of5
    case code128, code39, code93, codabar
    case dataMatrix, qr, pdf417, aztec
    case gs1DataBar, gs1DataBarExpanded, gs1DataBarLimited
    case other

    /// Maps VisionKit / Vision identifiers (e.g. "VNBarcodeSymbologyEAN13") and AVFoundation raw values
    /// (e.g. "org.gs1.EAN-13") by comparing a lower-cased alphanumeric form.
    public init(identifier: String) {
        var key = identifier.lowercased()
        for prefix in ["vnbarcodesymbology", "org.gs1.", "org.iso.", "org.ansi.", "com.apple.avfoundation."] {
            if key.hasPrefix(prefix) { key.removeFirst(prefix.count) }
        }
        key = key.filter { $0.isLetter || $0.isNumber }
        switch key {
        case "ean13": self = .ean13
        case "ean8": self = .ean8
        case "upca": self = .upcA
        case "upce": self = .upcE
        case "itf14": self = .itf14
        case "i2of5", "i2of5checksum", "interleaved2of5": self = .interleaved2of5
        case "code128": self = .code128
        case "code39", "code39checksum", "code39fullascii", "code39fullasciichecksum": self = .code39
        case "code93", "code93i": self = .code93
        case "codabar": self = .codabar
        case "datamatrix": self = .dataMatrix
        case "qr", "qrcode", "microqr": self = .qr
        case "pdf417", "micropdf417": self = .pdf417
        case "aztec": self = .aztec
        case "gs1databar": self = .gs1DataBar
        case "gs1databarexpanded": self = .gs1DataBarExpanded
        case "gs1databarlimited": self = .gs1DataBarLimited
        default: self = .other
        }
    }

    /// Symbologies that normally carry GS1 element strings rather than a bare GTIN.
    var carriesGS1ElementStrings: Bool {
        switch self {
        case .dataMatrix, .code128, .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited, .qr: return true
        default: return false
        }
    }
}

/// How the digits were presented on the pack.
public enum BarcodeFormat: String, Codable, Sendable {
    case ean8, upcE, upcA, ean13, gtin14
    case gs1ElementString, gs1DigitalLink
}

public struct BarcodeCandidate: Hashable, Sendable {
    public let gtin: GTIN
    public let format: BarcodeFormat
    /// The digits as read, e.g. the 8-digit UPC-E rather than its expansion.
    public let original: String

    public init(gtin: GTIN, format: BarcodeFormat, original: String) {
        self.gtin = gtin
        self.format = format
        self.original = original
    }
}

public enum BarcodeIssue: Equatable, Sendable {
    case empty
    case containsNonDigits
    case unsupportedLength(Int)
    /// `suggestions` are valid codes one edit away (corrected check digit or one adjacent swap), for manual entry.
    case badCheckDigit(expected: Int, suggestions: [String])
    /// A URL, SSCC or other payload that carries no product GTIN.
    case notAProductCode
}

public enum BarcodeNormalization: Equatable, Sendable {
    /// Usually one candidate. An 8-digit code read without a symbology can be EAN-8 or UPC-E; both are returned.
    case valid([BarcodeCandidate])
    case invalid(BarcodeIssue)

    public var candidates: [BarcodeCandidate] {
        if case let .valid(list) = self { return list }
        return []
    }
}

/// Everything the app learns from one scan.
public struct ScanInterpretation: Equatable, Sendable {
    public let normalization: BarcodeNormalization
    /// Present when the payload was a GS1 element string or Digital Link; carries lot, dates and weights.
    public let gs1: GS1ElementString?
}

public enum BarcodeNormalizer {
    /// Normalizes a scanned or typed payload to GTIN candidates.
    /// - Parameter preferUPCE: order for the EAN-8 / UPC-E ambiguity when both readings have a valid check digit.
    public static func normalize(
        _ raw: String,
        symbology: BarcodeSymbology? = nil,
        preferUPCE: Bool = false
    ) -> BarcodeNormalization {
        interpret(raw, symbology: symbology, preferUPCE: preferUPCE).normalization
    }

    public static func interpret(
        _ raw: String,
        symbology: BarcodeSymbology? = nil,
        preferUPCE: Bool = false
    ) -> ScanInterpretation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let (text, identifier) = splitSymbologyIdentifier(trimmed)
        if text.isEmpty { return ScanInterpretation(normalization: .invalid(.empty), gs1: nil) }
        let gs1Hint = (symbology?.carriesGS1ElementStrings ?? false) || gs1Identifiers.contains(identifier ?? "")

        let lowered = text.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            guard let link = GS1DigitalLink.parse(text), let gtin = link.gtin else {
                return ScanInterpretation(normalization: .invalid(.notAProductCode), gs1: nil)
            }
            let candidate = BarcodeCandidate(gtin: gtin, format: .gs1DigitalLink, original: gtin.digits14)
            return ScanInterpretation(normalization: .valid([candidate]), gs1: link)
        }

        let compact = text.filter { !$0.isWhitespace && $0 != "-" }

        let startsLikeElementString = (text.hasPrefix("01") || text.hasPrefix("02")) && compact.count >= 16
        let explicitElementString = text.contains("(") || text.contains(GS1ElementString.groupSeparator)
        if explicitElementString || startsLikeElementString {
            switch GS1ElementString.parse(text) {
            case let .success(parsed):
                guard let gtin = parsed.gtin else {
                    return ScanInterpretation(normalization: .invalid(.notAProductCode), gs1: parsed)
                }
                let candidate = BarcodeCandidate(gtin: gtin, format: .gs1ElementString, original: gtin.digits14)
                return ScanInterpretation(normalization: .valid([candidate]), gs1: parsed)
            case .failure:
                let reason: BarcodeIssue = (explicitElementString || gs1Hint || symbology != nil) ? .notAProductCode : .containsNonDigits
                return ScanInterpretation(normalization: .invalid(reason), gs1: nil)
            }
        }

        guard GS1.isASCIIDigits(compact) else {
            return ScanInterpretation(normalization: .invalid(.containsNonDigits), gs1: nil)
        }
        return ScanInterpretation(
            normalization: normalizeDigits(compact, symbology: symbology, preferUPCE: preferUPCE),
            gs1: nil
        )
    }

    /// ISO 15424 identifiers that mark a GS1 element string: GS1-128, GS1 DataMatrix, GS1 QR, GS1 DataBar.
    static let gs1Identifiers: Set<String> = ["]C1", "]d2", "]Q3", "]e0"]

    /// Splits off an ISO 15424 symbology identifier such as "]d2" (GS1 DataMatrix), "]C1" (GS1-128),
    /// "]Q3" (GS1 QR) or "]E0" (EAN/UPC) from the payload.
    static func splitSymbologyIdentifier(_ text: String) -> (payload: String, identifier: String?) {
        let chars = Array(text)
        if chars.count >= 3, chars[0] == "]", chars[1].isLetter, chars[2].isLetter || chars[2].isNumber {
            return (String(chars.dropFirst(3)), String(chars.prefix(3)))
        }
        return (text, nil)
    }

    static func strippingSymbologyIdentifier(_ text: String) -> String {
        splitSymbologyIdentifier(text).payload
    }

    static func normalizeDigits(_ digits: String, symbology: BarcodeSymbology?, preferUPCE: Bool) -> BarcodeNormalization {
        switch digits.count {
        case 8:
            return normalizeEightDigits(digits, symbology: symbology, preferUPCE: preferUPCE)
        case 12, 13, 14:
            guard let gtin = GTIN(digits) else { return .invalid(badCheck(digits)) }
            let format: BarcodeFormat = digits.count == 12 ? .upcA : (digits.count == 13 ? .ean13 : .gtin14)
            return .valid([BarcodeCandidate(gtin: gtin, format: format, original: digits)])
        default:
            return .invalid(.unsupportedLength(digits.count))
        }
    }

    private static func normalizeEightDigits(_ digits: String, symbology: BarcodeSymbology?, preferUPCE: Bool) -> BarcodeNormalization {
        let ean8 = GTIN(digits).map { BarcodeCandidate(gtin: $0, format: .ean8, original: digits) }
        let upcE = GTIN(upcE: digits).map { BarcodeCandidate(gtin: $0, format: .upcE, original: digits) }

        switch symbology {
        case .some(.ean8):
            return ean8.map { .valid([$0]) } ?? .invalid(badCheck(digits))
        case .some(.upcE):
            return upcE.map { .valid([$0]) } ?? .invalid(badCheck(digits))
        default:
            var found: [BarcodeCandidate] = []
            if preferUPCE {
                found = [upcE, ean8].compactMap { $0 }
            } else {
                found = [ean8, upcE].compactMap { $0 }
            }
            return found.isEmpty ? .invalid(badCheck(digits)) : .valid(found)
        }
    }

    private static func badCheck(_ digits: String) -> BarcodeIssue {
        let body = String(digits.dropLast())
        let expected = GS1.checkDigit(forBody: body) ?? 0
        return .badCheckDigit(expected: expected, suggestions: suggestions(forInvalid: digits))
    }

    /// Valid codes one edit away from a mistyped code: the corrected check digit, then single adjacent swaps.
    public static func suggestions(forInvalid digits: String, limit: Int = 5) -> [String] {
        guard GS1.isASCIIDigits(digits), [8, 12, 13, 14].contains(digits.count), !GS1.isValid(digits) else { return [] }
        var result: [String] = []
        if let corrected = GS1.appendingCheckDigit(to: String(digits.dropLast())), corrected != digits {
            result.append(corrected)
        }
        var chars = Array(digits)
        for index in 0..<(chars.count - 1) where chars[index] != chars[index + 1] {
            chars.swapAt(index, index + 1)
            let swapped = String(chars)
            chars.swapAt(index, index + 1)
            if GS1.isValid(swapped), !result.contains(swapped) { result.append(swapped) }
        }
        return Array(result.prefix(limit))
    }
}
