import CaliberCore
import Combine
import Foundation

/// Device-local presentation only; no stored season flag or server activation.
@MainActor
final class SeasonalAppearanceModel: ObservableObject {
  @Published private(set) var appearance: SeasonalAppearance
  private let now: () -> Date
  private let timeZone: () -> TimeZone
  let testingReduceMotion: Bool

  init(
    now: @escaping () -> Date = { .now }, timeZone: @escaping () -> TimeZone = { .current },
    testingReduceMotion: Bool = false
  ) {
    self.now = now
    self.timeZone = timeZone
    self.testingReduceMotion = testingReduceMotion
    appearance = SeasonalAppearancePolicy.appearance(at: now(), timeZone: timeZone())
  }

  func refresh() {
    let next = SeasonalAppearancePolicy.appearance(at: now(), timeZone: timeZone())
    if appearance != next { appearance = next }
  }

  var secondsUntilLocalMidnight: TimeInterval? {
    let date = now()
    return SeasonalAppearancePolicy.nextLocalMidnight(after: date, timeZone: timeZone())
      .map { max(1, $0.timeIntervalSince(date) + 0.1) }
  }

  static func configured(testing: Bool) -> SeasonalAppearanceModel {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      if testing, let index = arguments.firstIndex(of: "--season-now"),
        arguments.indices.contains(index + 1),
        let date = ISO8601DateFormatter().date(from: arguments[index + 1])
      {
        let zone: TimeZone
        if let index = arguments.firstIndex(of: "--season-zone"),
          arguments.indices.contains(index + 1),
          let specified = TimeZone(identifier: arguments[index + 1])
        {
          zone = specified
        } else {
          zone = .current
        }
        return SeasonalAppearanceModel(
          now: { date }, timeZone: { zone },
          testingReduceMotion: arguments.contains("--season-reduce-motion"))
      }
    #endif
    return SeasonalAppearanceModel()
  }
}
