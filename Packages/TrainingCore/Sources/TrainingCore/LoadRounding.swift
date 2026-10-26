import Foundation

/// How a computed training load is snapped to something the lifter can actually put on the bar.
public enum LoadRounding: Equatable, Sendable {
    /// No rounding.
    case none
    /// Round to a multiple of `step` (for example 2.5 kg).
    case increment(Double)
    /// Round to a total the plate inventory can really load (exact integer plate math).
    case plates(bar: Double, inventory: [Plate])

    public enum Direction: Sendable {
        case nearest, up, down
    }

    public func round(_ weight: Double, direction: Direction = .nearest) -> Double {
        switch self {
        case .none:
            return weight

        case let .increment(step):
            guard step > 0 else { return weight }
            let quotient = weight / step
            switch direction {
            case .nearest: return quotient.rounded() * step
            case .up: return (quotient - 1e-9).rounded(.up) * step
            case .down: return (quotient + 1e-9).rounded(.down) * step
            }

        case let .plates(bar, inventory):
            let target = Int((weight * 100).rounded())
            let barUnits = Int((bar * 100).rounded())
            let neighbors = PlateCalculator.neighbors(of: target, bar: barUnits, inventory: inventory)
            let chosen: PlateLoad?
            switch direction {
            case .nearest: chosen = PlateCalculator.nearest(to: target, bar: barUnits, inventory: inventory)
            case .up: chosen = neighbors.above ?? neighbors.below
            case .down: chosen = neighbors.below ?? neighbors.above
            }
            guard let load = chosen else { return weight }
            return Double(load.total) / 100
        }
    }
}

/// Compact number text for the human-readable reasons ("102.5", not "102.500000").
func formatNumber(_ value: Double) -> String {
    let rounded = (value * 100).rounded() / 100
    if rounded == rounded.rounded() { return String(Int(rounded)) }
    return String(rounded)
}
