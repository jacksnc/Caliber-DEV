import CaliberCore
import Combine
import Foundation

/// Health values are transient and local. Only the person's explicit settings persist.
@MainActor
final class HealthEnergyModel: ObservableObject {
  @Published private(set) var readsEnabled: Bool
  @Published private(set) var adjustsGoal: Bool
  @Published private(set) var confirmedAllowance: Double?
  @Published private(set) var observation: DailyActiveEnergy?
  @Published private(set) var isRefreshing = false
  @Published private(set) var message: String?
  private let service: any ActiveEnergyService
  private let defaults: UserDefaults
  private var generation = 0
  var isAvailable: Bool { service.isAvailable }

  init(defaults: UserDefaults, service: any ActiveEnergyService) {
    self.defaults = defaults
    self.service = service
    readsEnabled = defaults.bool(forKey: "health.activeEnergy.read.v1")
    adjustsGoal = defaults.bool(forKey: "health.activeEnergy.adjust.v1")
    if defaults.object(forKey: "health.activeEnergy.allowance.v1") != nil {
      let saved = defaults.double(forKey: "health.activeEnergy.allowance.v1")
      if saved.isFinite && saved >= 0 { confirmedAllowance = saved }
    }
  }

  func confirmAllowance(_ value: Double) {
    guard value.isFinite, value >= 0 else { return }
    confirmedAllowance = value
    defaults.set(value, forKey: "health.activeEnergy.allowance.v1")
  }

  func setAdjustsGoal(_ value: Bool) {
    adjustsGoal = value && readsEnabled && confirmedAllowance != nil
    defaults.set(adjustsGoal, forKey: "health.activeEnergy.adjust.v1")
  }

  func disable() {
    generation += 1
    readsEnabled = false
    setAdjustsGoal(false)
    defaults.set(false, forKey: "health.activeEnergy.read.v1")
    observation = nil
    message = nil
  }

  func suppress() {
    generation += 1
    observation = nil
  }

  func connect() async {
    guard !isRefreshing else { return }
    generation += 1
    let token = generation
    isRefreshing = true
    defer { isRefreshing = false }
    do {
      try await service.requestReadAccess()
      guard token == generation else { return }
      readsEnabled = true
      defaults.set(true, forKey: "health.activeEnergy.read.v1")
      await fetch(token: token)
    } catch {
      guard token == generation else { return }
      observation = nil
      message = "Apple Health could not be opened. Your base goal is unchanged."
    }
  }

  func refresh() async {
    guard readsEnabled, !isRefreshing else { return }
    generation += 1
    let token = generation
    isRefreshing = true
    defer { isRefreshing = false }
    await fetch(token: token)
  }

  private func fetch(token: Int) async {
    let now = Date.now
    let zone = TimeZone.current
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let start = calendar.startOfDay(for: now)
    do {
      let value = try await service.activeKilocalories(from: start, to: now)
      guard token == generation, readsEnabled else { return }
      observation = value.map {
        DailyActiveEnergy(
          kilocalories: $0, dayStart: start, refreshedAt: now, timeZoneIdentifier: zone.identifier)
      }
      message =
        value == nil
        ? "No readable Active Energy is available. Check Health permissions and your device's recorded data. Your base goal is unchanged."
        : nil
    } catch {
      guard token == generation else { return }
      observation = nil
      message = "Active Energy could not be refreshed. Your base goal is unchanged."
    }
  }

  func goal(base: Double, at now: Date = .now) -> DailyEnergyGoal? {
    DailyEnergyAdjustmentCalculator.goal(
      base: base, enabled: readsEnabled && adjustsGoal, confirmedAllowance: confirmedAllowance,
      observation: observation, now: now)
  }
}
