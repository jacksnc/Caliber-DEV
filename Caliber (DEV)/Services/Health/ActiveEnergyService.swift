import Foundation

#if canImport(HealthKit)
  import HealthKit
#endif

@MainActor
protocol ActiveEnergyService {
  var isAvailable: Bool { get }
  func requestReadAccess() async throws
  /// nil means no readable data, which is different from a reported zero.
  func activeKilocalories(from start: Date, to end: Date) async throws -> Double?
}

enum ActiveEnergyServiceError: Error { case unavailable, requestFailed }

@MainActor
final class AppleActiveEnergyService: ActiveEnergyService {
  #if canImport(HealthKit)
    private let store = HKHealthStore()
    private let type = HKQuantityType(.activeEnergyBurned)
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestReadAccess() async throws {
      guard isAvailable else { throw ActiveEnergyServiceError.unavailable }
      // No write permission. Completion only confirms the request, not read authorization.
      try await store.requestAuthorization(toShare: [], read: [type])
    }

    func activeKilocalories(from start: Date, to end: Date) async throws -> Double? {
      guard isAvailable else { throw ActiveEnergyServiceError.unavailable }
      let predicate = HKQuery.predicateForSamples(
        withStart: start, end: end, options: .strictStartDate)
      return try await withCheckedThrowingContinuation { continuation in
        let query = HKStatisticsQuery(
          quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum
        ) { _, statistics, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(
              returning: statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()))
          }
        }
        // Read the single Active Energy series. Never also add workout totals or resting energy.
        store.execute(query)
      }
    }
  #else
    var isAvailable: Bool { false }
    func requestReadAccess() async throws { throw ActiveEnergyServiceError.unavailable }
    func activeKilocalories(from start: Date, to end: Date) async throws -> Double? {
      throw ActiveEnergyServiceError.unavailable
    }
  #endif
}

/// Simulator UI fixtures never request or read the owner's real Health data.
@MainActor
struct FixtureActiveEnergyService: ActiveEnergyService {
  var isAvailable = true
  var calories: Double? = 450
  func requestReadAccess() async throws {}
  func activeKilocalories(from start: Date, to end: Date) async throws -> Double? { calories }
}
