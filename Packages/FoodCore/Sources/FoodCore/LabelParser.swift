import Foundation

public enum LabelBasis: String, Codable, Sendable {
    case perServing, per100g, per100ml
}

public enum LabelConfidence: Int, Comparable, Sendable {
    case low = 0, medium = 1, high = 2

    public static func < (lhs: LabelConfidence, rhs: LabelConfidence) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum LabelRepair: Equatable, Sendable {
    /// "89" read for "8g": the trailing unit character was taken as a digit.
    case trailingUnitDigit(original: Double)
    /// "89" read for "8.9": the decimal point was lost.
    case decimalPoint(original: Double)
}

public struct LabelReading: Equatable, Sendable {
    public var nutrient: Nutrient
    /// Value in the nutrient's canonical unit.
    public var value: Double
    public var percentDailyValue: Double?
    /// The label printed "<1 g" or "less than 1 g"; `value` holds half the printed bound.
    public var wasLessThan: Bool
    public var repair: LabelRepair?
    public var confidence: LabelConfidence

    public init(
        nutrient: Nutrient,
        value: Double,
        percentDailyValue: Double? = nil,
        wasLessThan: Bool = false,
        repair: LabelRepair? = nil,
        confidence: LabelConfidence = .high
    ) {
        self.nutrient = nutrient
        self.value = value
        self.percentDailyValue = percentDailyValue
        self.wasLessThan = wasLessThan
        self.repair = repair
        self.confidence = confidence
    }
}

public enum LabelWarning: Equatable, Sendable {
    case missingCalories
    case missingMacros([Nutrient])
    /// The printed amount and %DV cannot both be right; the user should check this row.
    case percentDailyValueMismatch(Nutrient, parsed: Double)
    case energyMismatch(declaredKcal: Double, atwaterKcal: Double)
}

public struct ParsedLabel: Equatable, Sendable {
    public var basis: LabelBasis = .perServing
    public var readings: [Nutrient: LabelReading] = [:]
    public var servingText: String?
    public var serving: ServingSize?
    public var servingsPerContainer: Double?
    public var warnings: [LabelWarning] = []

    public init(
        basis: LabelBasis = .perServing,
        readings: [Nutrient: LabelReading] = [:],
        servingText: String? = nil,
        serving: ServingSize? = nil,
        servingsPerContainer: Double? = nil,
        warnings: [LabelWarning] = []
    ) {
        self.basis = basis
        self.readings = readings
        self.servingText = servingText
        self.serving = serving
        self.servingsPerContainer = servingsPerContainer
        self.warnings = warnings
    }

    public var nutrientSet: NutrientSet {
        NutrientSet(readings.mapValues { $0.value })
    }

    /// Rows the confirmation screen should highlight.
    public var needsConfirmation: [Nutrient] {
        readings.values.filter { $0.confidence < .high }.map(\.nutrient).sorted { $0.rawValue < $1.rawValue }
    }

    public var isUsable: Bool { nutrientSet.hasCoreMacros }
}

/// Parses text recognised from a nutrition-facts panel (US layout, with a per-100 g/ml European fallback).
///
/// OCR rarely returns clean text, so every amount that comes with a %Daily Value is cross-checked against the FDA
/// reference values (current and pre-2020), and the two classic misreads - "89" for "8g" and a lost decimal point -
/// are repaired only when the repaired number fits the %DV.
public enum LabelParser {
    // MARK: Reference data

    struct Spec {
        let nutrient: Nutrient
        let phrases: [String]
        /// Daily Values in the nutrient's canonical unit: current (2016 rule), then the pre-2020 value.
        let dailyValues: [Double]
        /// Label rounding slack in the nutrient's canonical unit.
        let slack: Double
        /// European tables quote salt; it is converted to sodium (salt x 0.4).
        var isSalt = false
    }

    static let usSpecs: [Spec] = [
        Spec(nutrient: .energyKcal, phrases: ["calories", "calorie"], dailyValues: [], slack: 0),
        Spec(nutrient: .fat, phrases: ["total fat", "fat total", "total lipid", "fat"], dailyValues: [78, 65], slack: 0.5),
        Spec(nutrient: .saturatedFat, phrases: ["saturated fat", "sat fat", "sat. fat", "saturated"], dailyValues: [20, 20], slack: 0.5),
        Spec(nutrient: .transFat, phrases: ["trans fat", "trans"], dailyValues: [], slack: 0.5),
        Spec(nutrient: .polyunsaturatedFat, phrases: ["polyunsaturated fat", "polyunsaturated"], dailyValues: [], slack: 0.5),
        Spec(nutrient: .monounsaturatedFat, phrases: ["monounsaturated fat", "monounsaturated"], dailyValues: [], slack: 0.5),
        Spec(nutrient: .cholesterol, phrases: ["cholesterol"], dailyValues: [300, 300], slack: 5),
        Spec(nutrient: .sodium, phrases: ["sodium"], dailyValues: [2300, 2400], slack: 5),
        Spec(nutrient: .carbohydrate, phrases: ["total carbohydrate", "total carbohydrates", "total carb", "carbohydrates", "carbohydrate"], dailyValues: [275, 300], slack: 0.5),
        Spec(nutrient: .fiber, phrases: ["dietary fiber", "dietary fibre", "fiber", "fibre"], dailyValues: [28, 25], slack: 0.5),
        Spec(nutrient: .sugarAlcohols, phrases: ["sugar alcohols", "sugar alcohol", "polyols"], dailyValues: [], slack: 0.5),
        Spec(nutrient: .addedSugars, phrases: ["added sugars", "added sugar"], dailyValues: [50], slack: 0.5),
        Spec(nutrient: .sugars, phrases: ["total sugars", "sugars", "sugar"], dailyValues: [], slack: 0.5),
        Spec(nutrient: .protein, phrases: ["protein"], dailyValues: [50, 50], slack: 0.5),
        Spec(nutrient: .vitaminD, phrases: ["vitamin d"], dailyValues: [20, 10], slack: 0.5),
        Spec(nutrient: .calcium, phrases: ["calcium"], dailyValues: [1300, 1000], slack: 20),
        Spec(nutrient: .iron, phrases: ["iron"], dailyValues: [18, 18], slack: 0.5),
        Spec(nutrient: .potassium, phrases: ["potassium"], dailyValues: [4700, 3500], slack: 20),
        Spec(nutrient: .magnesium, phrases: ["magnesium"], dailyValues: [420, 400], slack: 10),
        Spec(nutrient: .zinc, phrases: ["zinc"], dailyValues: [11, 15], slack: 0.5),
        Spec(nutrient: .vitaminC, phrases: ["vitamin c"], dailyValues: [90, 60], slack: 2),
    ]

    /// European tables per 100 g/ml: "Energy 1046 kJ / 250 kcal", "of which saturates", "Salt".
    static let euSpecs: [Spec] = [
        Spec(nutrient: .energyKcal, phrases: ["energy", "calories"], dailyValues: [], slack: 0),
        Spec(nutrient: .saturatedFat, phrases: ["of which saturates", "of which saturated", "saturates", "saturated fat", "saturated"], dailyValues: [], slack: 0),
        Spec(nutrient: .monounsaturatedFat, phrases: ["of which mono-unsaturates", "monounsaturates", "mono-unsaturates"], dailyValues: [], slack: 0),
        Spec(nutrient: .polyunsaturatedFat, phrases: ["of which polyunsaturates", "polyunsaturates", "poly-unsaturates"], dailyValues: [], slack: 0),
        Spec(nutrient: .fat, phrases: ["total fat", "fat"], dailyValues: [], slack: 0),
        Spec(nutrient: .sugars, phrases: ["of which sugars", "total sugars", "sugars"], dailyValues: [], slack: 0),
        Spec(nutrient: .sugarAlcohols, phrases: ["of which polyols", "polyols"], dailyValues: [], slack: 0),
        Spec(nutrient: .carbohydrate, phrases: ["carbohydrate", "carbohydrates"], dailyValues: [], slack: 0),
        Spec(nutrient: .fiber, phrases: ["fibre", "fiber", "dietary fibre"], dailyValues: [], slack: 0),
        Spec(nutrient: .protein, phrases: ["protein"], dailyValues: [], slack: 0),
        Spec(nutrient: .sodium, phrases: ["sodium"], dailyValues: [], slack: 0),
        Spec(nutrient: .sodium, phrases: ["salt equivalent", "salt"], dailyValues: [], slack: 0, isSalt: true),
    ]

    /// Fraction of the Daily Value that %DV rounding and manufacturer rounding can plausibly explain.
    static let dailyValueTolerance = 0.015

    // MARK: Entry points

    public static func parse(_ text: String) -> ParsedLabel {
        parse(lines: text.split(whereSeparator: { $0.isNewline }).map(String.init))
    }

    public static func parse(lines rawLines: [String]) -> ParsedLabel {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var label = ParsedLabel()

        let lowered = lines.map { $0.lowercased() }
        if lowered.contains(where: { $0.contains("per 100") || $0.contains("pro 100") || $0.contains("par 100") }) {
            label.basis = lowered.contains(where: { ($0.contains("per 100") && $0.contains("ml")) }) ? .per100ml : .per100g
        }
        parseServing(lines, lowered, into: &label)

        let specs = label.basis == .perServing ? usSpecs : euSpecs
        let phraseTable = specs.flatMap { spec in spec.phrases.map { (phrase: $0, spec: spec) } }
            .sorted { $0.phrase.count > $1.phrase.count }

        var index = 0
        while index < lines.count {
            let line = lines[index]
            if shouldSkip(lowered[index]) { index += 1; continue }
            guard let spec = phraseTable.first(where: { containsPhrase(lowered[index], $0.phrase) })?.spec,
                  label.readings[spec.nutrient] == nil else {
                index += 1
                continue
            }

            var tokens = Self.tokens(in: cutOldCaloriesFromFat(line))
            var consumed = 0
            // The amount sometimes sits on the next one or two lines ("Total Fat" / "8g" / "10%").
            while tokens.allSatisfy({ $0.isPercent }), consumed < 2, index + consumed + 1 < lines.count {
                let next = lowered[index + consumed + 1]
                if phraseTable.contains(where: { containsPhrase(next, $0.phrase) }) || shouldSkip(next) { break }
                consumed += 1
                tokens += Self.tokens(in: lines[index + consumed])
            }
            // A %DV that landed alone on the following line belongs to this row too.
            if consumed > 0 || !tokens.isEmpty, !tokens.contains(where: { $0.isPercent }), index + consumed + 1 < lines.count {
                let next = lowered[index + consumed + 1]
                let nextTokens = Self.tokens(in: lines[index + consumed + 1])
                if !nextTokens.isEmpty, nextTokens.allSatisfy({ $0.isPercent }),
                   !phraseTable.contains(where: { containsPhrase(next, $0.phrase) }) {
                    consumed += 1
                    tokens += nextTokens
                }
            }
            if let reading = makeReading(spec: spec, tokens: tokens, basis: label.basis, label: &label) {
                label.readings[spec.nutrient] = reading
            }
            index += 1 + consumed
        }

        finish(&label)
        return label
    }

    // MARK: Serving

    private static func parseServing(_ lines: [String], _ lowered: [String], into label: inout ParsedLabel) {
        for (index, line) in lowered.enumerated() {
            for marker in ["serving size", "serv. size", "serv size", "portion size"] {
                guard label.serving == nil, let range = line.range(of: marker) else { continue }
                var remainder = String(lines[index][range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: " :-"))
                if ServingParser.parse(remainder) == nil, index + 1 < lines.count {
                    remainder = lines[index + 1]
                }
                if let serving = ServingParser.parse(remainder) {
                    label.serving = serving
                    label.servingText = remainder
                }
            }
            if label.servingsPerContainer == nil, line.contains("per container") || line.contains("servings per") || line.contains("serving per") {
                if let number = tokens(in: line).first(where: { !$0.isPercent && $0.unit == nil }) {
                    label.servingsPerContainer = number.value
                }
            }
        }
    }

    // MARK: Line classification

    private static func shouldSkip(_ lowered: String) -> Bool {
        if lowered.contains("daily value") || lowered.contains("general nutrition advice") || lowered.contains("a day is used") { return true }
        if lowered.contains("serving size") || lowered.contains("servings per") || lowered.contains("serving per") || lowered.contains("per container") { return true }
        if lowered.contains("calorie"), lowered.contains("diet") || lowered.contains("a day") || lowered.contains("per day") { return true }
        if lowered.contains("not a significant source") || lowered.contains("percent daily") { return true }
        return false
    }

    private static func cutOldCaloriesFromFat(_ line: String) -> String {
        if let range = line.lowercased().range(of: "calories from") {
            return String(line[line.startIndex..<range.lowerBound])
        }
        return line
    }

    static func containsPhrase(_ lowered: String, _ phrase: String) -> Bool {
        var searchStart = lowered.startIndex
        while let range = lowered.range(of: phrase, range: searchStart..<lowered.endIndex) {
            let before = range.lowerBound == lowered.startIndex ? nil : lowered[lowered.index(before: range.lowerBound)]
            let after = range.upperBound == lowered.endIndex ? nil : lowered[range.upperBound]
            let boundaryBefore = before.map { !$0.isLetter } ?? true
            let boundaryAfter = after.map { !$0.isLetter } ?? true
            if boundaryBefore && boundaryAfter { return true }
            searchStart = range.upperBound
        }
        return false
    }

    // MARK: Tokens

    struct Token: Equatable {
        var value: Double
        var unit: String?      // normalised: g, mg, mcg, kcal, kj, cal
        var isPercent: Bool
        var lessThan: Bool
    }

    /// OCR confusions inside number-like chunks: "Og"/"Omg" are zero amounts; "1O" is 10.
    static func normalizeChunk(_ chunk: String) -> String {
        var chars = Array(chunk)
        if ["og", "omg", "omcg", "o%"].contains(chunk.lowercased()) {
            chars[0] = "0"
            return String(chars)
        }
        guard chars.contains(where: { $0.isASCII && $0.isNumber }) else { return chunk }
        for i in chars.indices {
            let previousIsDigit = i > 0 && chars[i - 1].isASCII && chars[i - 1].isNumber
            let nextIsDigit = i + 1 < chars.count && chars[i + 1].isASCII && chars[i + 1].isNumber
            if (chars[i] == "O" || chars[i] == "o"), previousIsDigit || nextIsDigit {
                chars[i] = "0"
            } else if (chars[i] == "l" || chars[i] == "I"), nextIsDigit {
                chars[i] = "1"
            }
        }
        return String(chars)
    }

    static func normalizeUnit(_ letters: String) -> String? {
        switch letters.lowercased() {
        case "g", "gr", "gm", "q": return "g"
        case "mg", "m9", "mq", "rng", "rn9", "mgs": return "mg"
        case "mcg", "mc9", "mcq", "ug", "µg", "μg", "u9": return "mcg"
        case "kcal", "kcals", "cal", "cals": return "kcal"
        case "kj": return "kj"
        default: return nil
        }
    }

    static func tokens(in line: String) -> [Token] {
        let chunks = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "|" }).map { normalizeChunk(String($0)) }
        var result: [Token] = []
        var index = 0
        while index < chunks.count {
            var found = tokens(inChunk: chunks[index])
            // A bare number followed by its unit or percent sign as a separate chunk: "8 g", "160 mg", "10 %".
            if let last = found.last, last.unit == nil, !last.isPercent, index + 1 < chunks.count {
                if chunks[index + 1] == "%" {
                    found[found.count - 1].isPercent = true
                    index += 1
                } else if let unit = normalizeUnit(chunks[index + 1]) {
                    found[found.count - 1].unit = unit
                    index += 1
                }
            }
            result += found
            index += 1
        }
        // "less than 1 g" marks the first amount as an upper bound.
        if line.lowercased().contains("less than"), let first = result.firstIndex(where: { !$0.isPercent }) {
            result[first].lessThan = true
        }
        return result
    }

    /// Splits a whitespace-free chunk such as "8g10%" or "160m9" into tokens.
    private static func tokens(inChunk chunk: String) -> [Token] {
        let chars = Array(chunk)
        var tokens: [Token] = []
        var i = 0
        while i < chars.count {
            var lessThan = false
            if (chars[i] == "<" || chars[i] == "≤"), i + 1 < chars.count {
                lessThan = true
                i += 1
            }
            guard i < chars.count, chars[i].isASCII, chars[i].isNumber || (chars[i] == "." && i + 1 < chars.count && chars[i + 1].isASCII && chars[i + 1].isNumber) else {
                i += 1
                continue
            }
            var numberText = ""
            var separatorSeen = false
            while i < chars.count {
                let c = chars[i]
                if c.isASCII, c.isNumber {
                    numberText.append(c)
                } else if (c == "." || c == ","), !separatorSeen, i + 1 < chars.count, chars[i + 1].isASCII, chars[i + 1].isNumber {
                    // "2,300" is a thousands group; "1,5" is a decimal comma.
                    if c == ",", i + 3 < chars.count, chars[(i + 1)...(i + 3)].allSatisfy({ $0.isASCII && $0.isNumber }) {
                        i += 1
                        continue
                    }
                    numberText.append(".")
                    separatorSeen = true
                } else {
                    break
                }
                i += 1
            }
            guard let value = Double(numberText) else { continue }

            if i < chars.count, chars[i] == "%" {
                tokens.append(Token(value: value, unit: nil, isPercent: true, lessThan: lessThan))
                i += 1
                continue
            }
            var letters = ""
            var j = i
            while j < chars.count, letters.count < 4, chars[j].isLetter || chars[j] == "µ" || chars[j] == "μ" || (chars[j] == "9" && !letters.isEmpty) {
                letters.append(chars[j])
                j += 1
            }
            if !letters.isEmpty, let unit = normalizeUnit(letters) {
                tokens.append(Token(value: value, unit: unit, isPercent: false, lessThan: lessThan))
                i = j
            } else {
                tokens.append(Token(value: value, unit: nil, isPercent: false, lessThan: lessThan))
            }
        }
        return tokens
    }

    // MARK: Readings

    private static func makeReading(spec: Spec, tokens: [Token], basis: LabelBasis, label: inout ParsedLabel) -> LabelReading? {
        if spec.nutrient == .energyKcal { return energyReading(tokens) }
        guard let amount = tokens.first(where: { !$0.isPercent }) else { return nil }

        if spec.isSalt {
            let saltGrams = amount.unit == "mg" ? amount.value / 1000 : amount.value
            return LabelReading(nutrient: .sodium, value: NutrientSet.clean(saltGrams * NutritionReference.saltToSodium * 1000),
                                percentDailyValue: nil, wasLessThan: false, repair: nil, confidence: .medium)
        }

        var value = amount.value
        var confidence = LabelConfidence.high
        var repair: LabelRepair?
        let dv = tokens.first(where: { $0.isPercent })?.value

        if let canonical = spec.nutrient.unit.gramsPerUnit {
            if let unit = amount.unit, let from = unitGrams(unit) {
                value = value * from / canonical
            } else {
                confidence = .medium   // unit missing: assumed canonical
            }
        }

        if basis == .perServing, let dv, !spec.dailyValues.isEmpty {
            if !consistent(value, percent: dv, spec: spec) {
                if amount.unit == nil, let fixed = repaired(value, percent: dv, spec: spec) {
                    repair = fixed.repair
                    value = fixed.value
                    confidence = .medium
                } else {
                    label.warnings.append(.percentDailyValueMismatch(spec.nutrient, parsed: value))
                    confidence = .low
                }
            } else if confidence == .medium {
                confidence = .high   // %DV confirms the amount even though the unit was lost
            }
        }

        let bound = amount.lessThan
        if bound { value /= 2 }
        return LabelReading(nutrient: spec.nutrient, value: NutrientSet.clean(value), percentDailyValue: dv,
                            wasLessThan: bound, repair: repair, confidence: bound ? min(confidence, .medium) : confidence)
    }

    private static func energyReading(_ tokens: [Token]) -> LabelReading? {
        let amounts = tokens.filter { !$0.isPercent }
        guard !amounts.isEmpty else { return nil }
        if let kcal = amounts.first(where: { $0.unit == "kcal" }) {
            return LabelReading(nutrient: .energyKcal, value: kcal.value, percentDailyValue: nil, wasLessThan: false, repair: nil, confidence: .high)
        }
        if let kilojoules = amounts.first(where: { $0.unit == "kj" }) {
            let converted = NutrientSet.clean(kilojoules.value * NutritionReference.kcalPerKilojoule)
            return LabelReading(nutrient: .energyKcal, value: converted, percentDailyValue: nil, wasLessThan: false, repair: nil, confidence: .high)
        }
        let first = amounts[0]
        return LabelReading(nutrient: .energyKcal, value: first.value, percentDailyValue: nil, wasLessThan: first.lessThan, repair: nil,
                            confidence: first.value > 1500 ? .low : .high)
    }

    private static func unitGrams(_ unit: String) -> Double? {
        switch unit {
        case "g": return 1
        case "mg": return 1e-3
        case "mcg": return 1e-6
        default: return nil
        }
    }

    static func consistent(_ value: Double, percent: Double, spec: Spec) -> Bool {
        spec.dailyValues.contains { reference in
            abs(value - reference * percent / 100) <= reference * dailyValueTolerance + spec.slack
        }
    }

    /// Tries the two classic OCR misreads: the trailing unit character read as a digit ("89" for "8g", where 9, 8 and 6
    /// are the digits a "g" is mistaken for), then a lost decimal point ("45" for "4.5"). The decimal reading is only
    /// considered for gram nutrients; milligram and microgram amounts are printed as whole numbers.
    private static func repaired(_ value: Double, percent: Double, spec: Spec) -> (value: Double, repair: LabelRepair)? {
        if value >= 10, value == value.rounded(), [6, 8, 9].contains(Int(value) % 10) {
            let dropped = (value / 10).rounded(.down)
            if consistent(dropped, percent: percent, spec: spec) { return (dropped, .trailingUnitDigit(original: value)) }
        }
        if value >= 10, spec.nutrient.unit == .g {
            let shifted = value / 10
            if consistent(shifted, percent: percent, spec: spec) { return (shifted, .decimalPoint(original: value)) }
        }
        return nil
    }

    // MARK: Post-processing

    private static func finish(_ label: inout ParsedLabel) {
        if label.readings[.energyKcal] == nil { label.warnings.append(.missingCalories) }
        let missing = Nutrient.macros.filter { label.readings[$0] == nil }
        if !missing.isEmpty { label.warnings.append(.missingMacros(missing)) }

        let set = label.nutrientSet
        if let declared = set.calories, let computed = set.atwaterKcal {
            let allowed = max(NutritionValidator.energyAbsoluteTolerance, NutritionValidator.energyRelativeTolerance * max(declared, computed))
            if abs(declared - computed) > allowed {
                label.warnings.append(.energyMismatch(declaredKcal: declared, atwaterKcal: computed))
                if let current = label.readings[.energyKcal]?.confidence { label.readings[.energyKcal]?.confidence = min(current, .medium) }
            }
        }
    }
}
