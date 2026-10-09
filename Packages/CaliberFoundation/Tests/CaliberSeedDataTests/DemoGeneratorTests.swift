import Foundation
import Testing

@testable import CaliberSeedData

@Test func deterministicYearHasGapsAndPhases() throws {
  let end = ISO8601DateFormatter().date(from: "2024-12-31T12:00:00Z")!
  let first = try DemoGenerator.make(yearEnding: end)
  #expect(first == (try DemoGenerator.make(yearEnding: end)))
  #expect(first.days.count == 366)
  #expect(first.days.first?.localDate == "2024-01-01")
  #expect(first.days.last?.localDate == "2024-12-31")
  #expect(first.days.contains { $0.calories == nil })
  #expect(first.days.contains { $0.weightKG == nil })
  #expect(first.days.contains { $0.isDeload })
  #expect(Set(first.days.map(\.phase)) == ["Cut", "Maintenance"])
  #expect(first.simulation.contains { $0.missed })
  #expect(first != (try DemoGenerator.make(yearEnding: end, seed: 43)))
}
@Test(arguments: ["America/New_York", "Pacific/Auckland", "Asia/Kolkata"])
func civilDaysSurviveDST(_ zone: String) throws {
  let fixture = try DemoGenerator.make(
    yearEnding: Date(timeIntervalSince1970: 1_760_000_000), timeZone: TimeZone(identifier: zone)!)
  #expect(Set(fixture.days.map(\.localDate)).count == fixture.days.count)
  #expect((365...366).contains(fixture.days.count))
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: zone)!
  #expect(fixture.days.allSatisfy { calendar.component(.hour, from: $0.date) == 12 })
}
@Test func nonFiniteDateIsRejected() {
  #expect(throws: DemoGeneratorError.invalidDate) {
    try DemoGenerator.make(yearEnding: Date(timeIntervalSince1970: .infinity))
  }
}
