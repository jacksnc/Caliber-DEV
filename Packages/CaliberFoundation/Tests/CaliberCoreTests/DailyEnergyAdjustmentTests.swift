import Foundation
import Testing

@testable import CaliberCore

private let energyNow = Date(timeIntervalSince1970: 1_793_552_400)
private let energyZone = TimeZone(secondsFromGMT: 0)!
private func energyReading(_ value: Double, age: TimeInterval = 0) -> DailyActiveEnergy {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = energyZone
  return .init(
    kilocalories: value, dayStart: calendar.startOfDay(for: energyNow),
    refreshedAt: energyNow.addingTimeInterval(-age), timeZoneIdentifier: energyZone.identifier)
}
private func energyGoal(
  allowance: Double? = 300, reading: DailyActiveEnergy? = energyReading(450), enabled: Bool = true
) -> DailyEnergyGoal? {
  DailyEnergyAdjustmentCalculator.goal(
    base: 2000, enabled: enabled, confirmedAllowance: allowance, observation: reading,
    now: energyNow, timeZone: energyZone)
}

@Test func activityAdjustmentAddsOnlyAboveConfirmedAllowance() {
  let result = energyGoal()
  #expect(result?.base == 2000)
  #expect(result?.adjustment == 150)
  #expect(result?.total == 2150)
  #expect(result?.status == .applied)
  #expect(energyGoal(reading: energyReading(200))?.total == 2000)
  #expect(energyGoal(reading: energyReading(300))?.total == 2000)
  #expect(energyGoal(allowance: 0)?.total == 2450)
  // Re-reading is replacement, not an additive exercise credit.
  #expect(energyGoal() == energyGoal())
}

@Test func activityAdjustmentRequiresBothOptInAndConfirmedAllowance() {
  #expect(energyGoal(enabled: false)?.status == .off)
  #expect(energyGoal(allowance: nil)?.status == .needsAllowance)
  #expect(energyGoal(reading: nil)?.status == .noData)
  #expect(energyGoal(reading: nil)?.total == 2000)
}

@Test(arguments: [-1.0, Double.nan, Double.infinity])
func activityAdjustmentRejectsInvalidValues(_ value: Double) {
  #expect(energyGoal(reading: energyReading(value))?.status == .invalidData)
  #expect(energyGoal(allowance: value)?.status == .needsAllowance)
}

@Test func activityAdjustmentExpiresAtFifteenMinutesAndLocalDayOrTimezoneChange() {
  #expect(energyGoal(reading: energyReading(450, age: 900))?.status == .stale)
  #expect(energyGoal(reading: energyReading(450, age: -1))?.status == .stale)
  let midnight = Calendar(identifier: .gregorian).startOfDay(for: energyNow).addingTimeInterval(
    86400)
  #expect(
    DailyEnergyAdjustmentCalculator.goal(
      base: 2000, enabled: true, confirmedAllowance: 300, observation: energyReading(450),
      now: midnight, timeZone: energyZone)?.status == .stale)
  #expect(
    DailyEnergyAdjustmentCalculator.goal(
      base: 2000, enabled: true, confirmedAllowance: 300, observation: energyReading(450),
      now: energyNow, timeZone: TimeZone(identifier: "America/New_York")!)?.status == .stale)
}

@Test func activityAdjustmentRejectsInvalidBaseAndOverflow() {
  #expect(
    DailyEnergyAdjustmentCalculator.goal(
      base: .nan, enabled: true, confirmedAllowance: 0, observation: nil, now: energyNow) == nil)
  #expect(
    DailyEnergyAdjustmentCalculator.goal(
      base: .greatestFiniteMagnitude, enabled: true, confirmedAllowance: 0,
      observation: energyReading(.greatestFiniteMagnitude), now: energyNow,
      timeZone: energyZone)?.status == .invalidData)
}
