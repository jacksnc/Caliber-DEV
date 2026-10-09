import Foundation
import HeliosTime

/// Muscle regions (brief TRN-60, 21 regions).
public enum Muscle: String, CaseIterable, Hashable, Sendable {
    case upperChest, chest
    case lats, traps, upperBack, lowerBack
    case frontDelts, sideDelts, rearDelts
    case biceps, triceps, forearms
    case abs, obliques
    case glutes, quads, hamstrings, adductors, abductors, calves
    case neck
}

/// How one exercise loads one muscle. Primary movers default to 1.0, synergists to 0.5 (editable per exercise).
public struct MuscleInvolvement: Hashable, Sendable {
    public let muscle: Muscle
    public let isPrimary: Bool
    public let weight: Double

    public init(muscle: Muscle, isPrimary: Bool, weight: Double? = nil) {
        self.muscle = muscle
        self.isPrimary = isPrimary
        self.weight = weight ?? (isPrimary ? 1.0 : 0.5)
    }

    public static func primary(_ muscle: Muscle) -> MuscleInvolvement {
        MuscleInvolvement(muscle: muscle, isPrimary: true)
    }

    public static func secondary(_ muscle: Muscle, weight: Double = 0.5) -> MuscleInvolvement {
        MuscleInvolvement(muscle: muscle, isPrimary: false, weight: weight)
    }
}

public struct VolumeSet: Hashable, Sendable {
    public let date: LocalDate
    public let kind: SetKind
    public let weight: Double
    public let reps: Int
    /// Reps in reserve, when the user logged it.
    public let rir: Double?
    public let involvement: [MuscleInvolvement]

    public init(
        date: LocalDate,
        kind: SetKind = .working,
        weight: Double,
        reps: Int,
        rir: Double? = nil,
        involvement: [MuscleInvolvement]
    ) {
        self.date = date
        self.kind = kind
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.involvement = involvement
    }
}

/// Set-counting rules (brief TRN-61).
public struct VolumeCountingPolicy: Sendable {
    /// false = "direct only" (primary movers count 1 set each); true = fractional (synergists count their weight).
    public var fractional: Bool
    /// When true, sets logged with RIR above `maxRIR` do not count. Sets with no logged RIR always count.
    public var hardSetsOnly: Bool
    public var maxRIR: Double
    public var countedKinds: Set<SetKind>

    public init(
        fractional: Bool = true,
        hardSetsOnly: Bool = false,
        maxRIR: Double = 4,
        countedKinds: Set<SetKind> = Set(SetKind.allCases).subtracting([.warmup])
    ) {
        self.fractional = fractional
        self.hardSetsOnly = hardSetsOnly
        self.maxRIR = maxRIR
        self.countedKinds = countedKinds
    }

    public static let standard = VolumeCountingPolicy()
}

public struct MuscleWeekStats: Equatable, Sendable {
    public let sets: Double
    public let tonnage: Double
    /// Distinct days in the week on which the muscle received counted work.
    public let trainingDays: Int

    public init(sets: Double, tonnage: Double, trainingDays: Int) {
        self.sets = sets
        self.tonnage = tonnage
        self.trainingDays = trainingDays
    }
}

public enum VolumeStatus: Sendable {
    case under, inRange, over
}

/// Weekly set target for a muscle. Neutral by design: it labels a range, it never scolds.
public struct VolumeTarget: Equatable, Sendable {
    public let low: Double
    public let high: Double

    public init(low: Double, high: Double) {
        self.low = low
        self.high = high
    }

    /// Common hypertrophy default of roughly 10-20 hard sets per muscle per week (editable per user).
    public static let defaultHypertrophy = VolumeTarget(low: 10, high: 20)

    public func status(for sets: Double) -> VolumeStatus {
        if sets < low { return .under }
        if sets > high { return .over }
        return .inRange
    }
}

public enum VolumeEngine {
    /// Per-muscle set contribution of a single set under `policy`.
    public static func contribution(of set: VolumeSet, policy: VolumeCountingPolicy = .standard) -> [Muscle: Double] {
        guard policy.countedKinds.contains(set.kind), set.reps >= 1 else { return [:] }
        if policy.hardSetsOnly, let rir = set.rir, rir > policy.maxRIR { return [:] }

        var result: [Muscle: Double] = [:]
        for involvement in set.involvement {
            if policy.fractional {
                result[involvement.muscle, default: 0] += involvement.weight
            } else if involvement.isPrimary {
                result[involvement.muscle, default: 0] += 1
            }
        }
        return result
    }

    private struct Accumulator {
        var sets = 0.0
        var tonnage = 0.0
        var days = Set<LocalDate>()
    }

    /// Weekly sets, tonnage and frequency per muscle, keyed by the first day of each week.
    /// `firstWeekday` uses ISO numbering (1 = Monday ... 7 = Sunday).
    public static func weekly(
        _ sets: [VolumeSet],
        firstWeekday: Int = 1,
        policy: VolumeCountingPolicy = .standard
    ) -> [LocalDate: [Muscle: MuscleWeekStats]] {
        var accumulated: [LocalDate: [Muscle: Accumulator]] = [:]

        for set in sets {
            let shares = contribution(of: set, policy: policy)
            if shares.isEmpty { continue }
            let week = set.date.startOfWeek(firstWeekday: firstWeekday)
            for (muscle, share) in shares {
                var entry = accumulated[week]?[muscle] ?? Accumulator()
                entry.sets += share
                entry.tonnage += share * set.weight * Double(set.reps)
                entry.days.insert(set.date)
                accumulated[week, default: [:]][muscle] = entry
            }
        }

        return accumulated.mapValues { perMuscle in
            perMuscle.mapValues { entry in
                MuscleWeekStats(sets: entry.sets, tonnage: entry.tonnage, trainingDays: entry.days.count)
            }
        }
    }
}
