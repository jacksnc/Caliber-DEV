import Foundation

/// A kind of plate in a gym's inventory. All weights are integers in hundredths of the working
/// unit (2.5 kg -> 250, 45 lb -> 4500) so the arithmetic is exact and never shows float artifacts.
public struct Plate: Hashable, Sendable {
    public let size: Int
    /// How many identical *pairs* (one per side) are available.
    public let pairs: Int

    public init(size: Int, pairs: Int) {
        self.size = size
        self.pairs = pairs
    }
}

public struct PlateLoad: Equatable, Sendable {
    public let bar: Int
    /// Plates on ONE side of the bar, heaviest first.
    public let perSide: [Int]

    public init(bar: Int, perSide: [Int]) {
        self.bar = bar
        self.perSide = perSide
    }

    public var total: Int { bar + 2 * perSide.reduce(0, +) }
}

public enum PlateCalculator {
    public struct Neighbors: Equatable, Sendable {
        public let below: PlateLoad?
        public let above: PlateLoad?

        public init(below: PlateLoad?, above: PlateLoad?) {
            self.below = below
            self.above = above
        }
    }

    /// For every per-side weight the inventory can make, the best plate list:
    /// fewest plates first, and among equals the one with heavier plates first.
    static func reachable(_ inventory: [Plate]) -> [Int: [Int]] {
        var best: [Int: [Int]] = [0: []]
        let ordered = inventory
            .filter { $0.size > 0 && $0.pairs > 0 }
            .sorted { $0.size > $1.size }

        for plate in ordered {
            var next = best
            for (sum, plates) in best {
                for count in 1...plate.pairs {
                    let candidate = (plates + Array(repeating: plate.size, count: count)).sorted(by: >)
                    let newSum = sum + count * plate.size
                    if let existing = next[newSum] {
                        let fewer = candidate.count < existing.count
                        let heavier = candidate.count == existing.count && existing.lexicographicallyPrecedes(candidate)
                        if fewer || heavier { next[newSum] = candidate }
                    } else {
                        next[newSum] = candidate
                    }
                }
            }
            best = next
        }
        return best
    }

    /// Exact load for `target` total weight, or nil if the inventory cannot make it.
    public static func load(target: Int, bar: Int, inventory: [Plate]) -> PlateLoad? {
        let diff = target - bar
        guard diff >= 0, diff % 2 == 0 else { return nil }
        guard let plates = reachable(inventory)[diff / 2] else { return nil }
        return PlateLoad(bar: bar, perSide: plates)
    }

    /// The closest loadable totals at or below and at or above `target`.
    public static func neighbors(of target: Int, bar: Int, inventory: [Plate]) -> Neighbors {
        let map = reachable(inventory)
        let keys = map.keys.sorted()
        func makeLoad(_ key: Int) -> PlateLoad { PlateLoad(bar: bar, perSide: map[key] ?? []) }

        let diff = target - bar
        if diff < 0 { return Neighbors(below: nil, above: makeLoad(0)) }

        let lowKey = diff / 2
        let highKey = (diff + 1) / 2
        let below = keys.last(where: { $0 <= lowKey })
        let above = keys.first(where: { $0 >= highKey })
        return Neighbors(below: below.map(makeLoad), above: above.map(makeLoad))
    }

    /// Nearest loadable weight; ties round down.
    public static func nearest(to target: Int, bar: Int, inventory: [Plate]) -> PlateLoad? {
        let n = neighbors(of: target, bar: bar, inventory: inventory)
        switch (n.below, n.above) {
        case let (below?, above?):
            return (target - below.total) <= (above.total - target) ? below : above
        case let (below?, nil):
            return below
        case let (nil, above?):
            return above
        default:
            return nil
        }
    }
}
