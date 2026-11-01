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
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = energyZone
  let midnight = calendar.startOfDay(for: energyNow).addingTimeInterval(86400)
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

@Test func activityCreditCannotCrossLocalMidnightEvenWhileFresh() {
  let zone = TimeZone(identifier: "America/New_York")!
  let before = ISO8601DateFormatter().date(from: "2026-11-02T04:59:30Z")!
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = zone
  let reading = DailyActiveEnergy(
    kilocalories: 450, dayStart: calendar.startOfDay(for: before), refreshedAt: before,
    timeZoneIdentifier: zone.identifier)
  let result = DailyEnergyAdjustmentCalculator.goal(
    base: 2000, enabled: true, confirmedAllowance: 300, observation: reading,
    now: before.addingTimeInterval(60), timeZone: zone)
  #expect(result?.status == .stale)
  #expect(result?.total == 2000)
}

@Test func activityCreditKeepsCanonicalKcalAndFractionalPrecision() {
  let fraction = energyGoal(reading: energyReading(300.4))
  #expect(abs((fraction?.adjustment ?? 0) - 0.4) < 1e-10)
  #expect(energyGoal(reading: energyReading(450, age: 899))?.status == .applied)
  #expect(energyGoal(allowance: 0, reading: energyReading(0))?.adjustment == 0)
  #expect(abs(UnitFormatting.energy(energyGoal()!.total, unit: .kilojoules) - 8995.6) < 1e-9)
}

@Test(arguments: ["2026-11-01T06:30:00Z", "2027-03-14T07:30:00Z"])
func activityCreditUsesLocalDayOnDSTTransition(_ date: String) {
  let now = ISO8601DateFormatter().date(from: date)!
  let zone = TimeZone(identifier: "America/New_York")!
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = zone
  let reading = DailyActiveEnergy(
    kilocalories: 450, dayStart: calendar.startOfDay(for: now),
    refreshedAt: now, timeZoneIdentifier: zone.identifier)
  #expect(
    DailyEnergyAdjustmentCalculator.goal(
      base: 2000, enabled: true, confirmedAllowance: 300,
      observation: reading, now: now, timeZone: zone)?.total == 2150)
}

@Test func activityCreditConservativelyRejectsDifferentTimezoneIdentifier() {
  #expect(
    DailyEnergyAdjustmentCalculator.goal(
      base: 2000, enabled: true, confirmedAllowance: 300, observation: energyReading(450),
      now: energyNow, timeZone: TimeZone(identifier: "Europe/London")!)?.status == .stale)
}
