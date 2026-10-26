import Foundation

public enum SetKind: String, CaseIterable, Hashable, Sendable {
    case warmup, working, topSet, backoff, drop, failure, amrap, cluster, restPause, myoRep, custom
}

public struct LoggedSet: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let completedAt: Date
    public let weight: Double
    public let reps: Int
    public let kind: SetKind
    public let rpe: Double?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        completedAt: Date,
        weight: Double,
        reps: Int,
        kind: SetKind = .working,
        rpe: Double? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.completedAt = completedAt
        self.weight = weight
        self.reps = reps
        self.kind = kind
        self.rpe = rpe
    }

    public var volume: Double { weight * Double(reps) }
}

/// Which sets count toward records, and how e1RM is computed for them.
public struct PRPolicy: Sendable {
    public var countedKinds: Set<SetKind>
    /// Highest rep count tracked in the rep-max grid.
    public var maxRepRecord: Int
    public var formula: OneRepMaxFormula
    public var useRPEAdjustment: Bool
    /// The brief excludes low-confidence (> 12 effective reps) sets from e1RM records by default.
    public var excludeLowConfidenceE1RM: Bool

    public static let defaultCountedKinds: Set<SetKind> = Set(SetKind.allCases).subtracting([.warmup])

    public init(
        countedKinds: Set<SetKind> = PRPolicy.defaultCountedKinds,
        maxRepRecord: Int = 12,
        formula: OneRepMaxFormula = .epley,
        useRPEAdjustment: Bool = false,
        excludeLowConfidenceE1RM: Bool = true
    ) {
        self.countedKinds = countedKinds
        self.maxRepRecord = maxRepRecord
        self.formula = formula
        self.useRPEAdjustment = useRPEAdjustment
        self.excludeLowConfidenceE1RM = excludeLowConfidenceE1RM
    }

    public static let standard = PRPolicy()

    func counts(_ set: LoggedSet) -> Bool {
        countedKinds.contains(set.kind) && set.weight > 0 && set.reps >= 1
    }

    func e1RM(_ set: LoggedSet) -> Double? {
        let rpe: Double? = useRPEAdjustment ? set.rpe : nil
        guard let estimate = OneRepMax.estimate(weight: set.weight, reps: set.reps, rpe: rpe, formula: formula) else {
            return nil
        }
        if excludeLowConfidenceE1RM && estimate.confidence == .low { return nil }
        return estimate.value
    }
}

public enum PRKind: Hashable, Sendable {
    case heaviestWeight(Double)
    case bestE1RM(Double)
    case bestSetVolume(Double)
    /// Best weight for at least `reps` reps.
    case repRecord(reps: Int, weight: Double)
}

public struct PRResult: Equatable, Sendable {
    public let kinds: [PRKind]
    /// True when there was no earlier counted set, so nothing can be "beaten" yet.
    public let isFirstEntry: Bool

    public init(kinds: [PRKind], isFirstEntry: Bool) {
        self.kinds = kinds
        self.isFirstEntry = isFirstEntry
    }

    public var isPR: Bool { !kinds.isEmpty }

    /// The rep record with the most reps, which is the one worth showing in the UI.
    public var headlineRepRecord: PRKind? {
        var best: PRKind?
        var bestReps = 0
        for kind in kinds {
            if case let .repRecord(reps, _) = kind, reps > bestReps {
                best = kind
                bestReps = reps
            }
        }
        return best
    }
}

public enum PRDetector {
    /// Evaluates one just-completed set against everything logged strictly before it.
    /// Rep records use the "at least N reps" rule: 100 x 8 also counts as a 100 record for 1...8 reps.
    public static func evaluate(_ set: LoggedSet, history: [LoggedSet], policy: PRPolicy = .standard) -> PRResult {
        guard policy.counts(set) else { return PRResult(kinds: [], isFirstEntry: false) }

        let prior = history.filter { $0.id != set.id && $0.completedAt < set.completedAt && policy.counts($0) }
        guard !prior.isEmpty else { return PRResult(kinds: [], isFirstEntry: true) }

        var kinds: [PRKind] = []

        let heaviest = prior.map { $0.weight }.max() ?? 0
        if set.weight > heaviest { kinds.append(.heaviestWeight(set.weight)) }

        if let estimate = policy.e1RM(set) {
            let best = prior.compactMap { policy.e1RM($0) }.max() ?? 0
            if estimate > best { kinds.append(.bestE1RM(estimate)) }
        }

        let bestVolume = prior.map { $0.volume }.max() ?? 0
        if set.volume > bestVolume { kinds.append(.bestSetVolume(set.volume)) }

        let top = min(set.reps, policy.maxRepRecord)
        if top >= 1 {
            for n in 1...top {
                let best = prior.filter { $0.reps >= n }.map { $0.weight }.max() ?? 0
                if set.weight > best { kinds.append(.repRecord(reps: n, weight: set.weight)) }
            }
        }
        return PRResult(kinds: kinds, isFirstEntry: false)
    }

    /// True when `sessionID` has more counted volume than every session that finished before it started.
    public static func isSessionVolumeRecord(sessionID: UUID, in sets: [LoggedSet], policy: PRPolicy = .standard) -> Bool {
        let counted = sets.filter { policy.counts($0) }
        let mine = counted.filter { $0.sessionID == sessionID }
        guard let start = mine.map({ $0.completedAt }).min() else { return false }

        let others = counted.filter { $0.sessionID != sessionID }
        let grouped = Dictionary(grouping: others, by: { $0.sessionID })
        let earlier = grouped.values.filter { group in
            (group.map({ $0.completedAt }).max() ?? Date.distantFuture) < start
        }
        guard !earlier.isEmpty else { return false }

        let best = earlier.map { group in group.reduce(0.0) { $0 + $1.volume } }.max() ?? 0
        let current = mine.reduce(0.0) { $0 + $1.volume }
        return current > best
    }
}

/// Everything the records screen needs, recomputed from raw history so edits and deletes stay correct.
public struct ExerciseRecords: Equatable, Sendable {
    public var heaviestWeight: Double
    public var bestE1RM: Double?
    public var bestSetVolume: Double
    public var bestSessionVolume: Double
    /// N -> best weight lifted for at least N reps.
    public var repMaxGrid: [Int: Double]

    public static func compute(from sets: [LoggedSet], policy: PRPolicy = .standard) -> ExerciseRecords {
        let counted = sets.filter { policy.counts($0) }

        var grid: [Int: Double] = [:]
        if policy.maxRepRecord >= 1 {
            for n in 1...policy.maxRepRecord {
                if let best = counted.filter({ $0.reps >= n }).map({ $0.weight }).max() {
                    grid[n] = best
                }
            }
        }

        let sessions = Dictionary(grouping: counted, by: { $0.sessionID })
        let bestSession = sessions.values.map { group in group.reduce(0.0) { $0 + $1.volume } }.max() ?? 0

        return ExerciseRecords(
            heaviestWeight: counted.map { $0.weight }.max() ?? 0,
            bestE1RM: counted.compactMap { policy.e1RM($0) }.max(),
            bestSetVolume: counted.map { $0.volume }.max() ?? 0,
            bestSessionVolume: bestSession,
            repMaxGrid: grid
        )
    }
}
