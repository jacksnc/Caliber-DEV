import Foundation

/// A read-only, same-day Health Active Energy observation, held in memory only.
public struct DailyActiveEnergy: Equatable, Sendable {
  public let kilocalories: Double
  public let dayStart: Date
  public let refreshedAt: Date
  public let timeZoneIdentifier: String

  public init(kilocalories: Double, dayStart: Date, refreshedAt: Date, timeZoneIdentifier: String) {
    self.kilocalories = kilocalories
    self.dayStart = dayStart
    self.refreshedAt = refreshedAt
    self.timeZoneIdentifier = timeZoneIdentifier
  }
}

public enum DailyEnergyAdjustmentStatus: Equatable, Sendable {
  case off, needsAllowance, noData, stale, invalidData, applied
}

public struct DailyEnergyGoal: Equatable, Sendable {
  public let base: Double
  public let adjustment: Double
  public var total: Double { base + adjustment }
  public let status: DailyEnergyAdjustmentStatus
}

/// Explicit allowance avoids adding activity already budgeted into the saved goal.
/// This is an opt-in device estimate, not a new TDEE calculation or a goal mutation.
public enum DailyEnergyAdjustmentCalculator {
  public static func goal(
    base: Double, enabled: Bool, confirmedAllowance: Double?, observation: DailyActiveEnergy?,
    now: Date, timeZone: TimeZone = .current
  ) -> DailyEnergyGoal? {
    guard base.isFinite, base > 0 else { return nil }
    func fallback(_ status: DailyEnergyAdjustmentStatus) -> DailyEnergyGoal {
      DailyEnergyGoal(base: base, adjustment: 0, status: status)
    }
    guard enabled else { return fallback(.off) }
    guard let allowance = confirmedAllowance, allowance.isFinite, allowance >= 0 else {
      return fallback(.needsAllowance)
    }
    guard let observation else { return fallback(.noData) }
    guard observation.kilocalories.isFinite, observation.kilocalories >= 0,
      observation.refreshedAt.timeIntervalSince1970.isFinite,
      observation.dayStart.timeIntervalSince1970.isFinite, now.timeIntervalSince1970.isFinite
    else { return fallback(.invalidData) }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let age = now.timeIntervalSince(observation.refreshedAt)
    guard observation.timeZoneIdentifier == timeZone.identifier,
      observation.dayStart == calendar.startOfDay(for: now),
      calendar.isDate(observation.refreshedAt, inSameDayAs: now), age >= 0, age < 900
    else { return fallback(.stale) }
    let adjustment = max(0, observation.kilocalories - allowance)
    guard (base + adjustment).isFinite else { return fallback(.invalidData) }
    return DailyEnergyGoal(base: base, adjustment: adjustment, status: .applied)
  }
}
