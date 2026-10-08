import Foundation

/// Uses only recorded, valid weigh-ins. Notes and photos never imply a weight.
@MainActor
struct WeightProgressSummary {
    let readings: [WeightEntry]

    init(entries: [WeightEntry]) {
        readings = entries.filter { $0.weightInPounds.isFinite && $0.weightInPounds > 0 }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    var latestWeightInPounds: Double? { readings.last?.weightInPounds }

    /// A positive number means an increase; a negative number means a decrease.
    var changeInPounds: Double? {
        guard readings.count > 1, let first = readings.first, let last = readings.last else { return nil }
        return last.weightInPounds - first.weightInPounds
    }
}
