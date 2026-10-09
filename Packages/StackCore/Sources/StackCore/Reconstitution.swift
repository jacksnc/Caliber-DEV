import Foundation

// Reconstitution and draw math (brief STK-06). This is arithmetic only: it never suggests a dose.
// All quantities are `Decimal` (fixed-point base 10), never binary floating point (brief §9.1).

public enum AmountUnit: String, CaseIterable, Sendable {
    case mcg, mg, iu

    /// Micrograms per one of this unit; nil for IU, which has no fixed mass conversion.
    var microgramsPerUnit: Decimal? {
        switch self {
        case .mcg: return 1
        case .mg: return 1000
        case .iu: return nil
        }
    }
}

public struct Amount: Equatable, Sendable {
    public let value: Decimal
    public let unit: AmountUnit

    public init(_ value: Decimal, _ unit: AmountUnit) {
        self.value = value
        self.unit = unit
    }

    /// The value expressed in `target`, or nil when the units cannot be converted (IU vs a mass).
    public func converted(to target: AmountUnit) -> Decimal? {
        if unit == target { return value }
        guard let from = unit.microgramsPerUnit, let to = target.microgramsPerUnit else { return nil }
        return value * from / to
    }
}

public struct Syringe: Equatable, Sendable {
    public let name: String
    public let unitsPerML: Decimal
    public let capacityUnits: Decimal

    public init(name: String, unitsPerML: Decimal, capacityUnits: Decimal) {
        self.name = name
        self.unitsPerML = unitsPerML
        self.capacityUnits = capacityUnits
    }

    public static let u100Half = Syringe(name: "U-100 0.3 mL", unitsPerML: 100, capacityUnits: 30)
    public static let u100Mid = Syringe(name: "U-100 0.5 mL", unitsPerML: 100, capacityUnits: 50)
    public static let u100Full = Syringe(name: "U-100 1 mL", unitsPerML: 100, capacityUnits: 100)
    public static let u40Full = Syringe(name: "U-40 1 mL", unitsPerML: 40, capacityUnits: 40)
}

public enum ReconstitutionError: Error, Equatable, Sendable {
    case nonPositiveInput
    case unitMismatch
    case invalidBlend
}

public enum ReconstitutionWarning: Equatable, Sendable {
    /// Under 2 syringe units is too small to measure reliably.
    case drawBelowMeasurable(units: Decimal)
    case drawExceedsSyringe(units: Decimal, capacity: Decimal)
    case doseExceedsVial
}

/// One line of the "show the math" view.
public struct CalculationStep: Equatable, Sendable {
    public let label: String
    public let expression: String
    public let result: String
}

public struct ReconstitutionResult: Equatable, Sendable {
    /// In the dose's unit per mL.
    public let concentration: Decimal
    public let drawML: Decimal
    public let syringeUnits: Decimal
    public let dosesPerVial: Decimal
    public let fullDosesPerVial: Int
    public let warnings: [ReconstitutionWarning]
    public let steps: [CalculationStep]
}

public struct BlendResult: Equatable, Sendable {
    public let drawML: Decimal
    public let syringeUnits: Decimal
    /// What each component receives in one draw, in the target dose's unit.
    public let componentDoses: [Decimal]
    public let warnings: [ReconstitutionWarning]
}

public enum ReconstitutionCalculator {
    public static let minimumMeasurableUnits: Decimal = 2

    public static func calculate(
        vial: Amount,
        diluentML: Decimal,
        dose: Amount,
        syringe: Syringe
    ) throws -> ReconstitutionResult {
        guard vial.value > 0, diluentML > 0, dose.value > 0, syringe.unitsPerML > 0 else {
            throw ReconstitutionError.nonPositiveInput
        }
        guard let vialInDoseUnit = vial.converted(to: dose.unit) else {
            throw ReconstitutionError.unitMismatch
        }

        let concentration = vialInDoseUnit / diluentML
        let draw = dose.value / concentration
        let units = draw * syringe.unitsPerML
        let doses = vialInDoseUnit / dose.value
        let unit = dose.unit.rawValue

        let steps = [
            CalculationStep(
                label: "Concentration",
                expression: "\(show(vialInDoseUnit)) \(unit) / \(show(diluentML)) mL",
                result: "\(show(concentration)) \(unit)/mL"
            ),
            CalculationStep(
                label: "Draw volume",
                expression: "\(show(dose.value)) \(unit) / \(show(concentration)) \(unit)/mL",
                result: "\(show(draw)) mL"
            ),
            CalculationStep(
                label: "Syringe units",
                expression: "\(show(draw)) mL x \(show(syringe.unitsPerML)) units/mL",
                result: "\(show(units)) units"
            ),
            CalculationStep(
                label: "Doses per vial",
                expression: "\(show(vialInDoseUnit)) \(unit) / \(show(dose.value)) \(unit)",
                result: show(doses)
            ),
        ]

        var warnings: [ReconstitutionWarning] = []
        if units < minimumMeasurableUnits { warnings.append(.drawBelowMeasurable(units: units)) }
        if units > syringe.capacityUnits {
            warnings.append(.drawExceedsSyringe(units: units, capacity: syringe.capacityUnits))
        }
        if dose.value > vialInDoseUnit { warnings.append(.doseExceedsVial) }

        return ReconstitutionResult(
            concentration: concentration,
            drawML: draw,
            syringeUnits: units,
            dosesPerVial: doses,
            fullDosesPerVial: wholePart(of: doses),
            warnings: warnings,
            steps: steps
        )
    }

    /// Reverse mode: how much diluent makes `dose` land on exactly `targetUnits` on the syringe.
    public static func diluentML(
        vial: Amount,
        dose: Amount,
        targetUnits: Decimal,
        syringe: Syringe
    ) throws -> Decimal {
        guard vial.value > 0, dose.value > 0, targetUnits > 0, syringe.unitsPerML > 0 else {
            throw ReconstitutionError.nonPositiveInput
        }
        guard let vialInDoseUnit = vial.converted(to: dose.unit) else {
            throw ReconstitutionError.unitMismatch
        }
        return targetUnits * vialInDoseUnit / (dose.value * syringe.unitsPerML)
    }

    /// A vial holding several components in a stated ratio (for example 1:1). The draw is sized so that
    /// component `targetIndex` receives `targetDose`; every component's share of that draw is reported.
    public static func calculateBlend(
        totalVial: Amount,
        ratios: [Decimal],
        diluentML: Decimal,
        targetIndex: Int,
        targetDose: Amount,
        syringe: Syringe
    ) throws -> BlendResult {
        guard totalVial.value > 0, diluentML > 0, targetDose.value > 0, syringe.unitsPerML > 0 else {
            throw ReconstitutionError.nonPositiveInput
        }
        guard ratios.count >= 2, ratios.allSatisfy({ $0 > 0 }), ratios.indices.contains(targetIndex) else {
            throw ReconstitutionError.invalidBlend
        }
        guard let totalInDoseUnit = totalVial.converted(to: targetDose.unit) else {
            throw ReconstitutionError.unitMismatch
        }

        let ratioSum = ratios.reduce(0, +)
        let componentAmounts = ratios.map { totalInDoseUnit * $0 / ratioSum }
        let draw = targetDose.value * diluentML / componentAmounts[targetIndex]
        let units = draw * syringe.unitsPerML
        let doses = componentAmounts.map { $0 / diluentML * draw }

        var warnings: [ReconstitutionWarning] = []
        if units < minimumMeasurableUnits { warnings.append(.drawBelowMeasurable(units: units)) }
        if units > syringe.capacityUnits {
            warnings.append(.drawExceedsSyringe(units: units, capacity: syringe.capacityUnits))
        }
        if targetDose.value > componentAmounts[targetIndex] { warnings.append(.doseExceedsVial) }

        return BlendResult(drawML: draw, syringeUnits: units, componentDoses: doses, warnings: warnings)
    }

    // MARK: - helpers

    private static func wholePart(of value: Decimal) -> Int {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .down)
        return NSDecimalNumber(decimal: output).intValue
    }

    /// Four decimal places, for the step-by-step display only.
    private static func show(_ value: Decimal) -> String {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 4, .plain)
        return "\(output)"
    }
}
