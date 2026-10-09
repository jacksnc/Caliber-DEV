import Foundation

/// Synthetic fixture values only. Never a person's health history or a protocol preset.
public struct DemoDay: Codable, Equatable, Sendable, Identifiable {
  public var id: String { localDate }
  public let localDate: String
  public let date: Date
  public let calories: Double?
  public let protein: Double?
  public let weightKG: Double?
  public let trainingVolumeKG: Double?
  public let trainingSets: Int?
  public let isDeload: Bool
  public let phase: String
  public init(
    localDate: String, date: Date, calories: Double?, protein: Double?, weightKG: Double?,
    trainingVolumeKG: Double?, trainingSets: Int?, isDeload: Bool, phase: String
  ) {
    self.localDate = localDate
    self.date = date
    self.calories = calories
    self.protein = protein
    self.weightKG = weightKG
    self.trainingVolumeKG = trainingVolumeKG
    self.trainingSets = trainingSets
    self.isDeload = isDeload
    self.phase = phase
  }
}

/// Arbitrary-unit markers demonstrate privacy-separated timelines, never real dosing.
public struct DemoSimulationEvent: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let date: Date
  public let localDate: String
  public let level: Double
  public let missed: Bool
  public init(id: String, date: Date, localDate: String, level: Double, missed: Bool) {
    self.id = id
    self.date = date
    self.localDate = localDate
    self.level = level
    self.missed = missed
  }
}

public struct DemoDataset: Codable, Equatable, Sendable {
  public let version: Int
  public let seed: UInt64
  public let timeZoneID: String
  public let days: [DemoDay]
  public let simulation: [DemoSimulationEvent]
  public init(
    version: Int = 1, seed: UInt64, timeZoneID: String, days: [DemoDay],
    simulation: [DemoSimulationEvent]
  ) {
    self.version = version
    self.seed = seed
    self.timeZoneID = timeZoneID
    self.days = days
    self.simulation = simulation
  }
}

/// All chart math sees source values; downsampling is a rendering concern only.
public struct ChartObservation: Identifiable, Equatable, Sendable {
  public let id: String
  public let date: Date
  public let value: Double?
  public init(id: String, date: Date, value: Double?) {
    self.id = id
    self.date = date
    self.value = value
  }
}
