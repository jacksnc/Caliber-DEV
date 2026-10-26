import Foundation

/// Small, dependency-free robust statistics (brief §9.3 and §3.5).
public enum Stats {
    public static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// Median absolute deviation (unscaled).
    public static func mad(_ values: [Double]) -> Double? {
        guard let center = median(values) else { return nil }
        return median(values.map { abs($0 - center) })
    }

    public struct Line: Equatable, Sendable {
        public let slope: Double
        public let intercept: Double
    }

    /// Theil-Sen estimator: the median of all pairwise slopes. Robust to outliers. Long series are
    /// evenly subsampled to `maxPoints` so the pairwise work stays bounded.
    public static func theilSen(x: [Double], y: [Double], maxPoints: Int = 1500) -> Line? {
        guard x.count == y.count, x.count >= 2 else { return nil }

        var xs = x
        var ys = y
        if x.count > maxPoints, maxPoints >= 2 {
            let step = Double(x.count - 1) / Double(maxPoints - 1)
            let picked = (0..<maxPoints).map { Int((Double($0) * step).rounded()) }
            xs = picked.map { x[$0] }
            ys = picked.map { y[$0] }
        }

        var slopes: [Double] = []
        slopes.reserveCapacity(xs.count * (xs.count - 1) / 2)
        for i in 0..<xs.count {
            for j in (i + 1)..<xs.count {
                let dx = xs[j] - xs[i]
                if dx != 0 { slopes.append((ys[j] - ys[i]) / dx) }
            }
        }
        guard let slope = median(slopes) else { return nil }
        let offsets = zip(xs, ys).map { pair in pair.1 - slope * pair.0 }
        return Line(slope: slope, intercept: median(offsets) ?? 0)
    }

    /// Average ranks (ties share the mean of the ranks they span), 1-based.
    public static func ranks(_ values: [Double]) -> [Double] {
        let order = values.indices.sorted { values[$0] < values[$1] }
        var result = [Double](repeating: 0, count: values.count)
        var i = 0
        while i < order.count {
            var j = i
            while j + 1 < order.count && values[order[j + 1]] == values[order[i]] { j += 1 }
            let average = Double(i + j) / 2 + 1
            for k in i...j { result[order[k]] = average }
            i = j + 1
        }
        return result
    }

    public static func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= 2 else { return nil }
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n
        var sxy = 0.0
        var sxx = 0.0
        var syy = 0.0
        for i in x.indices {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            sxy += dx * dy
            sxx += dx * dx
            syy += dy * dy
        }
        guard sxx > 0, syy > 0 else { return nil }
        return sxy / (sxx * syy).squareRoot()
    }

    public static func spearman(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count else { return nil }
        return pearson(ranks(x), ranks(y))
    }

    /// Deterministic generator so bootstrap results are reproducible (and testable).
    public struct SplitMix64: RandomNumberGenerator {
        private var state: UInt64

        public init(seed: UInt64) { state = seed }

        public mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Percentile bootstrap interval for a paired statistic. Returns nil when too few resamples are valid.
    public static func bootstrapInterval(
        x: [Double],
        y: [Double],
        iterations: Int = 1000,
        seed: UInt64 = 1,
        level: Double = 0.95,
        statistic: ([Double], [Double]) -> Double?
    ) -> ClosedRange<Double>? {
        guard x.count == y.count, x.count >= 2, iterations >= 100, level > 0, level < 1 else { return nil }
        var rng = SplitMix64(seed: seed)
        var values: [Double] = []
        values.reserveCapacity(iterations)

        for _ in 0..<iterations {
            var sampleX: [Double] = []
            var sampleY: [Double] = []
            sampleX.reserveCapacity(x.count)
            sampleY.reserveCapacity(x.count)
            for _ in 0..<x.count {
                let index = Int.random(in: 0..<x.count, using: &rng)
                sampleX.append(x[index])
                sampleY.append(y[index])
            }
            if let value = statistic(sampleX, sampleY) { values.append(value) }
        }
        guard values.count >= iterations / 2 else { return nil }

        values.sort()
        let tail = (1 - level) / 2
        let low = values[Int((tail * Double(values.count - 1)).rounded())]
        let high = values[Int(((1 - tail) * Double(values.count - 1)).rounded())]
        return low...high
    }
}
