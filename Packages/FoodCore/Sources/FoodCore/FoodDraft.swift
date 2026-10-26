import Foundation

/// What the "add this product" screen collects when a barcode is unknown: a name, optional brand, and the
/// nutrition panel read by the label scanner (and corrected by the user).
public struct FoodDraft: Equatable, Sendable {
    public var gtin: GTIN?
    public var name: String
    public var brand: String?
    public var label: ParsedLabel
    /// The pack size ("340 g"), typed by the user or read from the front of the package.
    public var packageSizeText: String?
    /// Corrections made on the confirmation screen, applied over the OCR readings.
    public var corrections: [Nutrient: Double]
    public var servingOverrideText: String?

    public init(
        gtin: GTIN? = nil,
        name: String = "",
        brand: String? = nil,
        label: ParsedLabel = ParsedLabel(),
        packageSizeText: String? = nil,
        corrections: [Nutrient: Double] = [:],
        servingOverrideText: String? = nil
    ) {
        self.gtin = gtin
        self.name = name
        self.brand = brand
        self.label = label
        self.packageSizeText = packageSizeText
        self.corrections = corrections
        self.servingOverrideText = servingOverrideText
    }
}

public enum DraftIssue: Error, Equatable, Sendable {
    case nameRequired
    case caloriesRequired
    case macrosRequired([Nutrient])
    case negativeValue(Nutrient)
}

public enum FoodDraftBuilder {
    /// Builds a food record from a draft. A food needs a name, calories and the three macros; everything else is optional.
    /// When the label is per serving and the serving weight (or volume) is known, the matching per-100 g (or ml) block
    /// is derived so the food can be logged by weight too.
    public static func build(_ draft: FoodDraft, now: Date = Date()) -> Result<FoodRecord, DraftIssue> {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .failure(.nameRequired) }

        var values = draft.label.nutrientSet
        for (nutrient, value) in draft.corrections { values[nutrient] = value }
        for nutrient in values.nutrients where (values[nutrient] ?? 0) < 0 { return .failure(.negativeValue(nutrient)) }
        guard values.calories != nil else { return .failure(.caloriesRequired) }
        let missing = Nutrient.macros.filter { values[$0] == nil }
        guard missing.isEmpty else { return .failure(.macrosRequired(missing)) }

        let serving = draft.servingOverrideText.flatMap(ServingParser.parse) ?? draft.label.serving
        var record = FoodRecord(
            id: "label:\(draft.gtin?.digits14 ?? "x\(stableHash(name + (draft.brand ?? "")))")",
            gtin: draft.gtin,
            name: name,
            brand: draft.brand?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            source: .labelScan,
            serving: serving,
            packageSize: draft.packageSizeText.flatMap(ServingParser.parsePackage),
            fetchedAt: now
        )

        switch draft.label.basis {
        case .per100g:
            record.per100g = values
        case .per100ml:
            record.per100ml = values
        case .perServing:
            record.perServing = values
            if let grams = serving?.grams, grams > 0 {
                record.per100g = values.scaled(by: 100 / grams)
            } else if let milliliters = serving?.milliliters, milliliters > 0 {
                record.per100ml = values.scaled(by: 100 / milliliters)
            }
        }
        record.flags = NutritionValidator.validate(record)
        return .success(record)
    }

    /// FNV-1a: stable across launches and platforms, unlike Swift's randomised `hashValue`.
    static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
