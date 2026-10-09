import Foundation
import CaliberTime

public struct CorrelationResult: Equatable, Sendable {
    public let rho: Double
    public let confidenceInterval: ClosedRange<Double>?
    public let pairs: Int
    public let lagDays: Int
    /// Paired days as a fraction of the shorter series.
    public let coverage: Double
}

/// Correlation explorer (VZ-X2): Spearman rho with a bootstrap interval, a minimum-pairs gate and an
/// optional lag. It reports association only; the UI must say "association, not cause".
public enum CorrelationExplorer {
    public static let minimumPairs = 14
    public static let caveat = "Association, not cause."

    /// Pairs `a[d]` with `b[d + lagDays]` for every day present in both series.
    public static func analyze(
        a: [LocalDate: Double],
        b: [LocalDate: Double],
        lagDays: Int = 0,
        iterations: Int = 1000,
        seed: UInt64 = 1
    ) -> CorrelationResult? {
        var xs: [Double] = []
        var ys: [Double] = []
        for date in a.keys.sorted() {
            guard let x = a[date], let y = b[date.addingDays(lagDays)] else { continue }
            xs.append(x)
            ys.append(y)
        }
        guard xs.count >= minimumPairs, let rho = Stats.spearman(xs, ys) else { return nil }

        let interval = Stats.bootstrapInterval(
            x: xs, y: ys, iterations: iterations, seed: seed, statistic: { Stats.spearman($0, $1) }
        )
        let shorter = max(1, min(a.count, b.count))
        return CorrelationResult(
            rho: rho,
            confidenceInterval: interval,
            pairs: xs.count,
            lagDays: lagDays,
            coverage: Double(xs.count) / Double(shorter)
        )
    }
}

/// Dose-cycle overlay (VZ-X9): average of a daily series by days since the most recent dose.
public enum DoseCycleOverlay {
    public struct Bucket: Equatable, Sendable {
        public let daysSinceDose: Int
        public let mean: Double
        public let count: Int
    }

    /// Days before the first dose are ignored. Buckets run 0...`maxDays` and empty buckets are omitted.
    public static func averageByDaysSinceDose(
        series: [LocalDate: Double],
        doseDates: [LocalDate],
        maxDays: Int = 7
    ) -> [Bucket] {
        let doses = doseDates.sorted()
        guard !doses.isEmpty, maxDays >= 0 else { return [] }

        var sums = [Int: Double]()
        var counts = [Int: Int]()
        for (date, value) in series {
            guard let last = doses.last(where: { $0 <= date }) else { continue }
            let elapsed = date.epochDay - last.epochDay
            guard elapsed <= maxDays else { continue }
            sums[elapsed, default: 0] += value
            counts[elapsed, default: 0] += 1
        }
        return counts.keys.sorted().map { day in
            Bucket(daysSinceDose: day, mean: (sums[day] ?? 0) / Double(counts[day] ?? 1), count: counts[day] ?? 0)
        }
    }
}
