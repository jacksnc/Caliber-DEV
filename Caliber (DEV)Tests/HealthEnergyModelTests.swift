import CaliberCore
import XCTest

@testable import Caliber__DEV_

@MainActor
final class HealthEnergyModelTests: XCTestCase {
  private func defaults() -> UserDefaults {
    let name = "Caliber.HealthEnergy.Tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    addTeardownBlock { defaults.removePersistentDomain(forName: name) }
    return defaults
  }

  func testDefaultsRequireAllowanceAndSeparateExplicitAdjustmentChoice() async throws {
    let preferences = defaults()
    let model = HealthEnergyModel(defaults: preferences, service: FixtureActiveEnergyService())
    XCTAssertFalse(model.readsEnabled)
    XCTAssertFalse(model.adjustsGoal)
    XCTAssertNil(model.confirmedAllowance)
    model.setAdjustsGoal(true)
    XCTAssertFalse(model.adjustsGoal)
    await model.connect()
    XCTAssertEqual(model.observation?.kilocalories, 450)
    model.setAdjustsGoal(true)
    XCTAssertFalse(model.adjustsGoal)
    model.confirmAllowance(300)
    model.setAdjustsGoal(true)
    XCTAssertEqual(model.goal(base: 2000)?.total, 2150)
    await model.refresh()
    XCTAssertEqual(model.goal(base: 2000)?.total, 2150)
    let restored = HealthEnergyModel(defaults: preferences, service: FixtureActiveEnergyService())
    XCTAssertTrue(restored.readsEnabled)
    XCTAssertTrue(restored.adjustsGoal)
    XCTAssertEqual(restored.confirmedAllowance, 300)
    XCTAssertNil(restored.observation)  // Health values are never persisted.
    XCTAssertEqual(restored.goal(base: 2000)?.total, 2000)
    model.disable()
    XCTAssertNil(model.observation)
    XCTAssertFalse(model.adjustsGoal)
    XCTAssertEqual(model.goal(base: 2000)?.total, 2000)
  }

  func testNoReadableDataDoesNotBecomeReportedZero() async {
    let model = HealthEnergyModel(
      defaults: defaults(), service: FixtureActiveEnergyService(calories: nil))
    model.confirmAllowance(300)
    await model.connect()
    model.setAdjustsGoal(true)
    XCTAssertNil(model.observation)
    XCTAssertEqual(model.goal(base: 2000)?.status, .noData)
    XCTAssertNotNil(model.message)
  }

  func testNewHealthReadingReplacesPreviousCreditRatherThanAccumulatingIt() async {
    let service = MutableEnergyService()
    let model = HealthEnergyModel(defaults: defaults(), service: service)
    model.confirmAllowance(300)
    await model.connect()
    model.setAdjustsGoal(true)
    XCTAssertEqual(model.goal(base: 2000)?.total, 2150)
    service.value = 600
    await model.refresh()
    XCTAssertEqual(model.goal(base: 2000)?.total, 2300)
    service.value = 200
    await model.refresh()
    XCTAssertEqual(model.goal(base: 2000)?.total, 2000)
  }

  func testDisconnectDiscardsAnInFlightRead() async {
    let service = SuspendedEnergyService()
    let model = HealthEnergyModel(defaults: defaults(), service: service)
    let connect = Task { await model.connect() }
    for _ in 0..<100 where service.pending == nil { await Task.yield() }
    XCTAssertNotNil(service.pending)
    model.disable()
    service.pending?.resume(returning: 450)
    service.pending = nil
    await connect.value
    XCTAssertFalse(model.readsEnabled)
    XCTAssertNil(model.observation)
  }
}

@MainActor
private final class SuspendedEnergyService: ActiveEnergyService {
  let isAvailable = true
  var pending: CheckedContinuation<Double?, any Error>?
  func requestReadAccess() async throws {}
  func activeKilocalories(from start: Date, to end: Date) async throws -> Double? {
    try await withCheckedThrowingContinuation { pending = $0 }
  }
}

@MainActor
private final class MutableEnergyService: ActiveEnergyService {
  let isAvailable = true
  var value: Double? = 450
  func requestReadAccess() async throws {}
  func activeKilocalories(from start: Date, to end: Date) async throws -> Double? { value }
}
