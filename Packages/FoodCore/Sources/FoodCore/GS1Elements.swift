import Foundation

public struct GS1Element: Equatable, Sendable {
    public let ai: String
    public let value: String

    public init(ai: String, value: String) {
        self.ai = ai
        self.value = value
    }
}

public enum GS1ParseError: Error, Equatable, Sendable {
    case empty
    case unknownIdentifier(String)
    case truncated(ai: String)
    case invalidCharacters(ai: String)
    case tooLong(ai: String)
    case malformedParentheses
}

/// A calendar date from a GS1 date element (YYMMDD). `day == nil` means "last day of the month" (DD = 00).
public struct GS1Date: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int?

    /// Last calendar day of the month, resolving DD = 00.
    public var resolvedDay: Int {
        day ?? GS1Date.daysInMonth(year: year, month: month)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        default:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        }
    }

    /// Resolves the two-digit year to the century that puts it within 50 years before to 49 years after `referenceYear`.
    static func parse(_ yymmdd: String, referenceYear: Int) -> GS1Date? {
        guard let digits = GS1.digitValues(yymmdd), digits.count == 6 else { return nil }
        let yy = digits[0] * 10 + digits[1]
        let month = digits[2] * 10 + digits[3]
        let day = digits[4] * 10 + digits[5]
        guard (1...12).contains(month) else { return nil }

        var year = referenceYear - referenceYear % 100 + yy
        if year > referenceYear + 49 { year -= 100 }
        if year < referenceYear - 50 { year += 100 }

        if day == 0 { return GS1Date(year: year, month: month, day: nil) }
        guard day <= daysInMonth(year: year, month: month) else { return nil }
        return GS1Date(year: year, month: month, day: day)
    }
}

/// The element strings carried by GS1-128, GS1 DataMatrix, GS1 QR and GS1 Digital Link barcodes.
/// Only the application identifiers relevant to food packaging are recognised; anything else is a parse error
/// rather than a guess, so callers can fall back to the plain GTIN path.
public struct GS1ElementString: Equatable, Sendable {
    public static let groupSeparator: Character = "\u{1D}"

    public let elements: [GS1Element]

    public init(elements: [GS1Element]) {
        self.elements = elements
    }

    public func value(of ai: String) -> String? {
        elements.first { $0.ai == ai }?.value
    }

    /// GTIN of the item (AI 01), or of the contents of a logistics unit (AI 02).
    public var gtin: GTIN? {
        (value(of: "01") ?? value(of: "02")).flatMap { GTIN($0) }
    }

    public var lot: String? { value(of: "10") }
    public var serial: String? { value(of: "21") }

    public func productionDate(referenceYear: Int? = nil) -> GS1Date? { date("11", referenceYear) }
    public func packagingDate(referenceYear: Int? = nil) -> GS1Date? { date("13", referenceYear) }
    public func bestBefore(referenceYear: Int? = nil) -> GS1Date? { date("15", referenceYear) }
    public func sellBy(referenceYear: Int? = nil) -> GS1Date? { date("16", referenceYear) }
    public func expiry(referenceYear: Int? = nil) -> GS1Date? { date("17", referenceYear) }

    private func date(_ ai: String, _ referenceYear: Int?) -> GS1Date? {
        let year = referenceYear ?? GS1ElementString.currentYear()
        return value(of: ai).flatMap { GS1Date.parse($0, referenceYear: year) }
    }

    /// Net weight in kilograms (AI 3100-3105; the last digit is the decimal-point position).
    public var netWeightKilograms: Double? { decimalValue(family: "310") }
    /// Net weight in pounds (AI 3200-3205).
    public var netWeightPounds: Double? { decimalValue(family: "320") }

    private func decimalValue(family: String) -> Double? {
        for element in elements where element.ai.hasPrefix(family) && element.ai.count == 4 {
            guard let places = Int(element.ai.suffix(1)), let raw = Double(element.value) else { continue }
            return raw / pow(10, Double(places))
        }
        return nil
    }

    /// Number of items in the pack (AI 30 variable count, or AI 37 count of contained trade items).
    public var itemCount: Int? {
        (value(of: "30") ?? value(of: "37")).flatMap { Int($0) }
    }

    static func currentYear() -> Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    // MARK: Application identifier table

    struct Spec {
        let fixedLength: Int?
        let maxLength: Int
        let numeric: Bool
    }

    static let specs: [String: Spec] = {
        var table: [String: Spec] = [
            "00": Spec(fixedLength: 18, maxLength: 18, numeric: true),
            "01": Spec(fixedLength: 14, maxLength: 14, numeric: true),
            "02": Spec(fixedLength: 14, maxLength: 14, numeric: true),
            "10": Spec(fixedLength: nil, maxLength: 20, numeric: false),
            "20": Spec(fixedLength: 2, maxLength: 2, numeric: true),
            "21": Spec(fixedLength: nil, maxLength: 20, numeric: false),
            "22": Spec(fixedLength: nil, maxLength: 20, numeric: false),
            "30": Spec(fixedLength: nil, maxLength: 8, numeric: true),
            "37": Spec(fixedLength: nil, maxLength: 8, numeric: true),
            "240": Spec(fixedLength: nil, maxLength: 30, numeric: false),
            "241": Spec(fixedLength: nil, maxLength: 30, numeric: false),
            "400": Spec(fixedLength: nil, maxLength: 30, numeric: false),
            "420": Spec(fixedLength: nil, maxLength: 20, numeric: false),
            "421": Spec(fixedLength: nil, maxLength: 12, numeric: false),
            "7003": Spec(fixedLength: 10, maxLength: 10, numeric: true),
        ]
        for date in ["11", "12", "13", "15", "16", "17"] {
            table[date] = Spec(fixedLength: 6, maxLength: 6, numeric: true)
        }
        for places in 0...5 {
            table["310\(places)"] = Spec(fixedLength: 6, maxLength: 6, numeric: true)
            table["320\(places)"] = Spec(fixedLength: 6, maxLength: 6, numeric: true)
        }
        for gln in 410...417 {
            table["\(gln)"] = Spec(fixedLength: 13, maxLength: 13, numeric: true)
        }
        for internalUse in 91...99 {
            table["\(internalUse)"] = Spec(fixedLength: nil, maxLength: 90, numeric: false)
        }
        return table
    }()

    // MARK: Parsing

    /// Parses either the human-readable form `(01)09506000134352(17)261231(10)LOT7`
    /// or the raw form with group separators (ASCII 29) after variable-length elements.
    public static func parse(_ raw: String) -> Result<GS1ElementString, GS1ParseError> {
        let text = BarcodeNormalizer.strippingSymbologyIdentifier(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        if text.isEmpty { return .failure(.empty) }
        return text.hasPrefix("(") ? parseParenthesized(text) : parseRaw(text)
    }

    private static func validate(ai: String, value: String) -> GS1ParseError? {
        guard let spec = specs[ai] else { return .unknownIdentifier(ai) }
        if let fixed = spec.fixedLength {
            if value.count < fixed { return .truncated(ai: ai) }
            if value.count > fixed { return .tooLong(ai: ai) }
        } else {
            if value.isEmpty { return .truncated(ai: ai) }
            if value.count > spec.maxLength { return .tooLong(ai: ai) }
        }
        if spec.numeric, !GS1.isASCIIDigits(value) { return .invalidCharacters(ai: ai) }
        if !value.unicodeScalars.allSatisfy({ $0.value >= 0x21 && $0.value <= 0x7E }) { return .invalidCharacters(ai: ai) }
        return nil
    }

    private static func parseParenthesized(_ text: String) -> Result<GS1ElementString, GS1ParseError> {
        var elements: [GS1Element] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index] == "(", let close = text[index...].firstIndex(of: ")") else {
                return .failure(.malformedParentheses)
            }
            let ai = String(text[text.index(after: index)..<close])
            let valueStart = text.index(after: close)
            let valueEnd = text[valueStart...].firstIndex(of: "(") ?? text.endIndex
            let value = String(text[valueStart..<valueEnd])
            if let error = validate(ai: ai, value: value) { return .failure(error) }
            elements.append(GS1Element(ai: ai, value: value))
            index = valueEnd
        }
        return elements.isEmpty ? .failure(.empty) : .success(GS1ElementString(elements: elements))
    }

    private static func parseRaw(_ text: String) -> Result<GS1ElementString, GS1ParseError> {
        let chars = Array(text)
        var elements: [GS1Element] = []
        var position = 0

        while position < chars.count {
            if chars[position] == groupSeparator { position += 1; continue }

            var ai: String?
            for length in [2, 3, 4] where position + length <= chars.count {
                let candidate = String(chars[position..<(position + length)])
                if specs[candidate] != nil { ai = candidate; break }
            }
            guard let identifier = ai, let spec = specs[identifier] else {
                return .failure(.unknownIdentifier(String(chars[position..<min(position + 4, chars.count)])))
            }
            position += identifier.count

            let value: String
            if let fixed = spec.fixedLength {
                guard position + fixed <= chars.count else { return .failure(.truncated(ai: identifier)) }
                value = String(chars[position..<(position + fixed)])
                position += fixed
            } else {
                var end = position
                while end < chars.count, chars[end] != groupSeparator { end += 1 }
                value = String(chars[position..<end])
                position = end
            }
            if let error = validate(ai: identifier, value: value) { return .failure(error) }
            elements.append(GS1Element(ai: identifier, value: value))
        }
        return elements.isEmpty ? .failure(.empty) : .success(GS1ElementString(elements: elements))
    }
}

/// GS1 Digital Link URIs, e.g. `https://id.gs1.org/01/09506000134352/10/LOT7?17=261231`.
public enum GS1DigitalLink {
    /// Finds the `/01/<gtin14>` key in the path (any path prefix is allowed) and collects the remaining
    /// AI/value path pairs and numeric query parameters. Returns nil when the URL carries no valid GTIN.
    public static func parse(_ urlString: String) -> GS1ElementString? {
        guard let components = URLComponents(string: urlString) else { return nil }
        let segments = components.percentEncodedPath.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }

        guard let keyIndex = segments.indices.first(where: { index in
            segments[index] == "01" && index + 1 < segments.count && GTIN(segments[index + 1]) != nil
        }) else { return nil }

        var elements = [GS1Element(ai: "01", value: GTIN(segments[keyIndex + 1])!.digits14)]
        var index = keyIndex + 2
        while index + 1 < segments.count {
            let ai = segments[index]
            if GS1ElementString.specs[ai] != nil, ai != "01" {
                elements.append(GS1Element(ai: ai, value: segments[index + 1]))
            }
            index += 2
        }
        for item in components.queryItems ?? [] {
            if GS1ElementString.specs[item.name] != nil, let value = item.value {
                elements.append(GS1Element(ai: item.name, value: value))
            }
        }
        return GS1ElementString(elements: elements)
    }
}
