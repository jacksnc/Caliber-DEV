import CaliberCore
import Foundation

public enum DemoGeneratorError: Error, Equatable, Sendable {
  case invalidDate
  case unsupportedCalendarRange
}

/// Reproducible fictional fixtures. These are not targets, prescriptions or personal health data.
public enum DemoGenerator {
  /// Includes the supplied local day and the preceding 12 calendar months of day buckets.
  /// Dates are local noon so DST changes never turn a date label into the previous day.
  public static func make(
    yearEnding: Date = Date(), seed: UInt64 = 42, timeZone: TimeZone = .gmt
  ) throws -> DemoDataset {
    guard yearEnding.timeIntervalSince1970.isFinite else { throw DemoGeneratorError.invalidDate }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.locale = Locale(identifier: "en_US_POSIX")
    let year = calendar.component(.year, from: yearEnding)
    guard (1900...2200).contains(year) else { throw DemoGeneratorError.unsupportedCalendarRange }
    let lastDay = calendar.startOfDay(for: yearEnding)
    guard let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: lastDay),
      let start = calendar.date(byAdding: .month, value: -12, to: exclusiveEnd),
      let dayCount = calendar.dateComponents([.day], from: start, to: exclusiveEnd).day,
      (365...366).contains(dayCount)
    else { throw DemoGeneratorError.unsupportedCalendarRange }
    var random = SplitMix64(seed: seed)
    var days: [DemoDay] = []
    var simulation: [DemoSimulationEvent] = []
    days.reserveCapacity(dayCount)
    for offset in 0..<dayCount {
      guard let day = calendar.date(byAdding: .day, value: offset, to: start),
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)
      else {
        throw DemoGeneratorError.unsupportedCalendarRange
      }
      let components = calendar.dateComponents([.year, .month, .day, .weekday], from: noon)
      guard let y = components.year, let m = components.month, let d = components.day,
        let weekday = components.weekday
      else { throw DemoGeneratorError.unsupportedCalendarRange }
      let localDate = String(format: "%04d-%02d-%02d", y, m, d)
      let inCut = (100..<212).contains(offset)
      let deload =
        (56..<63).contains(offset) || (196..<203).contains(offset) || (308..<315).contains(offset)
      let scheduledTraining = [2, 4, 6].contains(weekday)
      let missingFood = offset % 17 == 0 || (244..<249).contains(offset)
      let missingWeight = offset % 5 == 0 || (160..<166).contains(offset)
      let calorieNoise = random.centered(amplitude: 230)
      let proteinNoise = random.centered(amplitude: 18)
      let weightNoise = random.centered(amplitude: 0.7)
      let volumeNoise = random.centered(amplitude: 450)
      let cutProgress = Double(min(max(offset - 100, 0), 112)) / 112.0
      let baseWeight = 87 - 5.2 * cutProgress + (offset >= 212 ? Double(offset - 212) * 0.004 : 0)
      let isTraining = scheduledTraining && offset % 29 != 0
      let volume =
        isTraining ? max(500, (deload ? 2_800 : 6_500) + Double(offset) * 3 + volumeNoise) : nil
      days.append(
        DemoDay(
          localDate: localDate, date: noon,
          calories: missingFood ? nil : rounded((inCut ? 2_180 : 2_600) + calorieNoise, places: 0),
          protein: missingFood ? nil : rounded(162 + proteinNoise, places: 0),
          weightKG: missingWeight ? nil : rounded(baseWeight + weightNoise, places: 2),
          trainingVolumeKG: volume.map { rounded($0, places: 0) },
          trainingSets: isTraining ? (deload ? 9 : 18) : nil,
          isDeload: deload, phase: inCut ? "Cut" : "Maintenance"
        ))
      // Arbitrary-unit markers test a private timeline. No substance, concentration,
      // route, recommended schedule, or human dose unit is represented by this signal.
      if offset % 9 == 3 {
        simulation.append(
          DemoSimulationEvent(
            id: "simulation-\(localDate)", date: noon, localDate: localDate,
            level: Double(1 + (offset / 90) % 3), missed: offset % 4 == 0
          ))
      }
    }
    return DemoDataset(
      seed: seed, timeZoneID: timeZone.identifier, days: days, simulation: simulation)
  }
  private static func rounded(_ value: Double, places: Int) -> Double {
    let factor = pow(10, Double(places))
    return (value * factor).rounded() / factor
  }
}

/// Stable across Swift versions; never relies on Swift's process-randomized hash values.
private struct SplitMix64 {
  var state: UInt64
  init(seed: UInt64) { state = seed }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
  mutating func centered(amplitude: Double) -> Double {
    let fraction = Double(next() >> 11) / Double(UInt64(1) << 53)
    return (fraction * 2 - 1) * amplitude
  }
}
