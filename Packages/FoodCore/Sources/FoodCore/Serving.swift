import Foundation

/// A serving or package size as printed on a label, with whatever metric equivalents could be derived.
public struct ServingSize: Equatable, Sendable, Codable {
    /// Leading amount as written ("2/3" -> 0.6667).
    public var quantity: Double
    /// Unit as written, lower-cased and normalised for the common measures ("g", "ml", "cup", "tbsp", "fl oz", "slice", ...).
    public var unit: String
    /// Mass of the whole `quantity` (not of a single unit), when known.
    public var grams: Double?
    /// Volume of the whole `quantity`, when known.
    public var milliliters: Double?
    /// Number of identical units for multipacks ("6 x 330 ml" -> 6), otherwise nil.
    public var count: Int?
    public var text: String

    public init(quantity: Double, unit: String, grams: Double? = nil, milliliters: Double? = nil, count: Int? = nil, text: String) {
        self.quantity = quantity
        self.unit = unit
        self.grams = grams
        self.milliliters = milliliters
        self.count = count
        self.text = text
    }

    /// Mass of the serving, using `densityGramsPerMilliliter` to convert a volume-only serving (1.0 for water-like drinks).
    public func gramsEstimate(densityGramsPerMilliliter: Double? = nil) -> Double? {
        if let grams { return grams }
        if let milliliters, let density = densityGramsPerMilliliter { return milliliters * density }
        return nil
    }
}

enum MeasureUnit: Equatable {
    case gram, milligram, kilogram, ounce, pound
    case milliliter, liter, deciliter, centiliter, fluidOunce, cup, tablespoon, teaspoon
    case household(String)

    static func parse(_ word: String) -> MeasureUnit {
        let key = word.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
        switch key {
        case "g", "gr", "gm", "gms", "gram", "grams", "gramme", "grammes": return .gram
        case "mg", "milligram", "milligrams": return .milligram
        case "kg", "kgs", "kilogram", "kilograms": return .kilogram
        case "oz", "ounce", "ounces": return .ounce
        case "lb", "lbs", "pound", "pounds": return .pound
        case "ml", "mls", "milliliter", "milliliters", "millilitre", "millilitres", "cc": return .milliliter
        case "l", "ltr", "liter", "liters", "litre", "litres": return .liter
        case "dl", "deciliter", "deciliters", "decilitre", "decilitres": return .deciliter
        case "cl", "centiliter", "centiliters", "centilitre", "centilitres": return .centiliter
        case "fl oz", "floz", "fl.oz", "fl. oz", "fluid ounce", "fluid ounces", "fl ounce", "fl ounces": return .fluidOunce
        case "cup", "cups": return .cup
        case "tbsp", "tbs", "tbl", "tbsps", "tablespoon", "tablespoons": return .tablespoon
        case "tsp", "tsps", "teaspoon", "teaspoons": return .teaspoon
        default: return .household(key)
        }
    }

    /// Recognises a known unit at the start of a phrase ("cup cooked" -> cup, "fl oz" -> fluid ounce);
    /// otherwise the whole phrase is a household unit ("slice", "bar", "about 12 chips" after noise removal).
    static func leading(in phrase: String) -> MeasureUnit {
        let whole = parse(phrase)
        if case .household = whole {
            let words = phrase.split(separator: " ").map(String.init)
            if words.count >= 2, case let two = parse(words[0] + " " + words[1]), !two.isHousehold { return two }
            if let first = words.first, case let one = parse(first), !one.isHousehold { return one }
        }
        return whole
    }

    var isHousehold: Bool {
        if case .household = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .gram: return "g"
        case .milligram: return "mg"
        case .kilogram: return "kg"
        case .ounce: return "oz"
        case .pound: return "lb"
        case .milliliter: return "ml"
        case .liter: return "l"
        case .deciliter: return "dl"
        case .centiliter: return "cl"
        case .fluidOunce: return "fl oz"
        case .cup: return "cup"
        case .tablespoon: return "tbsp"
        case .teaspoon: return "tsp"
        case let .household(word): return word
        }
    }

    func grams(_ value: Double) -> Double? {
        switch self {
        case .gram: return value
        case .milligram: return value / 1000
        case .kilogram: return value * 1000
        case .ounce: return value * 28.349523125
        case .pound: return value * 453.59237
        default: return nil
        }
    }

    /// FDA labeling equivalents are used for cups (240 mL), tablespoons (15 mL) and teaspoons (5 mL);
    /// fluid ounces use the physical US value.
    func milliliters(_ value: Double) -> Double? {
        switch self {
        case .milliliter: return value
        case .liter: return value * 1000
        case .deciliter: return value * 100
        case .centiliter: return value * 10
        case .fluidOunce: return value * 29.5735295625
        case .cup: return value * 240
        case .tablespoon: return value * 15
        case .teaspoon: return value * 5
        default: return nil
        }
    }

    var isMetricMass: Bool { self == .gram || self == .milligram || self == .kilogram }
    var isMetricVolume: Bool { self == .milliliter || self == .liter || self == .deciliter || self == .centiliter }
}

public enum ServingParser {
    private static let vulgarFractions: [Character: String] = [
        "½": " 1/2", "¼": " 1/4", "¾": " 3/4", "⅓": " 1/3", "⅔": " 2/3", "⅛": " 1/8", "⅜": " 3/8", "⅝": " 5/8",
        "⅞": " 7/8", "⅕": " 1/5", "⅖": " 2/5", "⅗": " 3/5", "⅘": " 4/5", "⅙": " 1/6", "⅚": " 5/6",
    ]

    private static let leadingNoise = [
        "serving size:", "serving size", "serv. size:", "serv size:", "per serving:", "per serving", "per", "about",
        "approximately", "approx.", "approx", "around", "ca.", "~",
    ]

    /// Parses a serving size such as "2/3 cup (55g)", "1 slice (28 g)", "8 fl oz (240 mL)", "30g" or "1 1/2 tbsp".
    public static func parse(_ text: String) -> ServingSize? {
        let normalized = normalize(text)
        let (outside, inside) = splitParentheses(normalized)

        var lead = outside.trimmingCharacters(in: .whitespaces)
        lead = stripLeadingNoise(lead)

        var chars = Array(lead)
        var index = 0
        let quantity = parseQuantity(chars, &index)
        let unitPhrase = String(chars[index...]).trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-"))
        chars = []

        let leadUnit: MeasureUnit? = unitPhrase.isEmpty ? nil : MeasureUnit.leading(in: unitPhrase)

        // Equivalents from parentheses, e.g. "(55g)", "(28g/1oz)", "(240 ml)". Metric ones are preferred.
        var metricGrams: Double?
        var metricMilliliters: Double?
        var imperialGrams: Double?
        var imperialMilliliters: Double?
        for group in inside {
            for piece in group.split(whereSeparator: { "/,;".contains($0) }) {
                guard let measure = parseMeasure(stripLeadingNoise(String(piece).trimmingCharacters(in: .whitespaces))) else { continue }
                if measure.unit.isMetricMass {
                    metricGrams = metricGrams ?? measure.unit.grams(measure.value)
                } else if measure.unit.isMetricVolume {
                    metricMilliliters = metricMilliliters ?? measure.unit.milliliters(measure.value)
                } else if measure.unit == .ounce || measure.unit == .pound {
                    imperialGrams = imperialGrams ?? measure.unit.grams(measure.value)
                } else if measure.unit == .fluidOunce {
                    imperialMilliliters = imperialMilliliters ?? measure.unit.milliliters(measure.value)
                }
            }
        }

        let amount: Double
        if let quantity {
            amount = quantity
        } else if metricGrams != nil || metricMilliliters != nil || imperialGrams != nil || imperialMilliliters != nil {
            amount = 1
        } else {
            return nil
        }

        // Precedence: a metric lead, then a metric parenthesis, then the lead converted from household/imperial,
        // then an imperial parenthesis.
        var leadMetricGrams: Double?
        var leadOtherGrams: Double?
        var leadMetricMilliliters: Double?
        var leadOtherMilliliters: Double?
        if let leadUnit {
            if leadUnit.isMetricMass { leadMetricGrams = leadUnit.grams(amount) } else { leadOtherGrams = leadUnit.grams(amount) }
            if leadUnit.isMetricVolume { leadMetricMilliliters = leadUnit.milliliters(amount) } else { leadOtherMilliliters = leadUnit.milliliters(amount) }
        }
        let grams = leadMetricGrams ?? metricGrams ?? leadOtherGrams ?? imperialGrams
        let milliliters = leadMetricMilliliters ?? metricMilliliters ?? leadOtherMilliliters ?? imperialMilliliters

        return ServingSize(
            quantity: round6(amount),
            unit: leadUnit?.label ?? "serving",
            grams: grams.map(round6),
            milliliters: milliliters.map(round6),
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Parses a package quantity such as "500 g", "1.5 l", "6 x 330 ml" or "4 x 125g". Multipacks report the total.
    public static func parsePackage(_ text: String) -> ServingSize? {
        let normalized = normalize(text)
        let separators: [Character] = ["x", "×", "*"]
        if let split = normalized.firstIndex(where: { separators.contains($0) }) {
            let countText = normalized[..<split].trimmingCharacters(in: .whitespaces)
            let rest = String(normalized[normalized.index(after: split)...])
            if let count = Int(countText), count > 1, count < 100, let unitSize = parse(rest) {
                return ServingSize(
                    quantity: round6(unitSize.quantity * Double(count)),
                    unit: unitSize.unit,
                    grams: unitSize.grams.map { round6($0 * Double(count)) },
                    milliliters: unitSize.milliliters.map { round6($0 * Double(count)) },
                    count: count,
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }
        return parse(text)
    }

    // MARK: Helpers

    private static func round6(_ value: Double) -> Double { (value * 1e6).rounded() / 1e6 }

    private static func normalize(_ text: String) -> String {
        var result = ""
        for character in text.lowercased() {
            if let fraction = vulgarFractions[character] {
                result += fraction
            } else if character == "\u{00A0}" {
                result += " "
            } else {
                result.append(character)
            }
        }
        // Keep "fl oz" together and tolerate "fl. oz." spellings.
        result = result.replacingOccurrences(of: "fl. oz.", with: "fl oz")
            .replacingOccurrences(of: "fl. oz", with: "fl oz")
            .replacingOccurrences(of: "fl.oz.", with: "fl oz")
            .replacingOccurrences(of: "fl.oz", with: "fl oz")
        while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripLeadingNoise(_ text: String) -> String {
        var current = text.trimmingCharacters(in: .whitespaces)
        var changed = true
        while changed {
            changed = false
            for prefix in leadingNoise where current.hasPrefix(prefix) {
                let remainder = current.dropFirst(prefix.count)
                // "per", "about" etc. only count as noise when a space, colon or digit follows.
                if let next = remainder.first, next == " " || next == ":" || next.isNumber || next == "." {
                    current = remainder.trimmingCharacters(in: CharacterSet(charactersIn: " :"))
                    changed = true
                    break
                } else if remainder.isEmpty {
                    current = ""
                    changed = true
                    break
                }
            }
        }
        return current
    }

    /// Splits "2/3 cup (55g)" into ("2/3 cup ", ["55g"]).
    private static func splitParentheses(_ text: String) -> (String, [String]) {
        var outside = ""
        var inside: [String] = []
        var depth = 0
        var current = ""
        for character in text {
            if character == "(" {
                depth += 1
                if depth == 1 { current = ""; continue }
            } else if character == ")" {
                if depth > 0 {
                    depth -= 1
                    if depth == 0 { inside.append(current); continue }
                }
            }
            if depth > 0 { current.append(character) } else { outside.append(character) }
        }
        if depth > 0 { inside.append(current) }
        return (outside, inside)
    }

    private struct Measure {
        let value: Double
        let unit: MeasureUnit
    }

    private static func parseMeasure(_ text: String) -> Measure? {
        let chars = Array(text)
        var index = 0
        guard let value = parseQuantity(chars, &index) else { return nil }
        let unitPhrase = String(chars[index...]).trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-"))
        guard !unitPhrase.isEmpty else { return nil }
        return Measure(value: value, unit: MeasureUnit.leading(in: unitPhrase))
    }

    /// Reads a quantity: integer, decimal (dot or comma), fraction, mixed number or range ("1-2" -> midpoint).
    /// Advances `index` past the number and any following spaces.
    static func parseQuantity(_ chars: [Character], _ index: inout Int) -> Double? {
        guard var value = parseSingleNumber(chars, &index) else { return nil }
        skipSpaces(chars, &index)

        // Mixed number "1 1/2": a whole number followed by a fraction.
        if value == value.rounded(), index < chars.count, chars[index].isNumber {
            var lookahead = index
            if let fractionValue = parseFraction(chars, &lookahead), fractionValue < 1 {
                value += fractionValue
                index = lookahead
                skipSpaces(chars, &index)
            }
        }

        // Range "1-2" or "1 to 2".
        if index < chars.count, chars[index] == "-" || chars[index] == "–" {
            var lookahead = index + 1
            skipSpaces(chars, &lookahead)
            if let upper = parseSingleNumber(chars, &lookahead), upper >= value {
                value = (value + upper) / 2
                index = lookahead
                skipSpaces(chars, &index)
            }
        }
        return value
    }

    private static func skipSpaces(_ chars: [Character], _ index: inout Int) {
        while index < chars.count, chars[index] == " " { index += 1 }
    }

    private static func parseFraction(_ chars: [Character], _ index: inout Int) -> Double? {
        var cursor = index
        var numerator = ""
        while cursor < chars.count, chars[cursor].isASCII, chars[cursor].isNumber { numerator.append(chars[cursor]); cursor += 1 }
        guard !numerator.isEmpty, cursor < chars.count, chars[cursor] == "/" else { return nil }
        cursor += 1
        var denominator = ""
        while cursor < chars.count, chars[cursor].isASCII, chars[cursor].isNumber { denominator.append(chars[cursor]); cursor += 1 }
        guard let top = Double(numerator), let bottom = Double(denominator), bottom != 0 else { return nil }
        index = cursor
        return top / bottom
    }

    private static func parseSingleNumber(_ chars: [Character], _ index: inout Int) -> Double? {
        var cursor = index
        guard cursor < chars.count else { return nil }

        var fractionCursor = cursor
        if let fraction = parseFraction(chars, &fractionCursor) {
            index = fractionCursor
            return fraction
        }

        var text = ""
        var separatorSeen = false
        while cursor < chars.count {
            let character = chars[cursor]
            if character.isASCII, character.isNumber {
                text.append(character)
            } else if (character == "." || character == ","), cursor + 1 < chars.count, chars[cursor + 1].isASCII, chars[cursor + 1].isNumber, !separatorSeen {
                // A comma followed by exactly three digits after a non-zero integer is a thousands separator ("1,000 g").
                if character == ",", isThousandsGroup(chars, at: cursor), text != "0", !text.isEmpty {
                    cursor += 1
                    continue
                }
                text.append(".")
                separatorSeen = true
            } else {
                break
            }
            cursor += 1
        }
        guard !text.isEmpty, let value = Double(text) else { return nil }
        index = cursor
        return value
    }

    private static func isThousandsGroup(_ chars: [Character], at comma: Int) -> Bool {
        guard comma + 3 < chars.count else { return false }
        guard chars[(comma + 1)...(comma + 3)].allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
        if comma + 4 < chars.count, chars[comma + 4].isASCII, chars[comma + 4].isNumber { return false }
        return true
    }
}
