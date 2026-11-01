import CaliberCore
import SwiftUI
import UIKit

private struct SeasonalAppearanceKey: EnvironmentKey {
  static let defaultValue = SeasonalAppearance.standard
}

private struct SeasonalTestingReduceMotionKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var seasonalTestingReduceMotion: Bool {
    get { self[SeasonalTestingReduceMotionKey.self] }
    set { self[SeasonalTestingReduceMotionKey.self] = newValue }
  }
  var seasonalAppearance: SeasonalAppearance {
    get { self[SeasonalAppearanceKey.self] }
    set { self[SeasonalAppearanceKey.self] = newValue }
  }
}

/// A single observer updates every screen/sheet; saved base appearance is untouched.
struct SeasonalAppearanceScope: ViewModifier {
  @ObservedObject var model: SeasonalAppearanceModel
  @Environment(\.scenePhase) private var phase
  @State private var scheduleRevision = 0

  private struct Schedule: Equatable {
    let active: Bool
    let revision: Int
  }

  func body(content: Content) -> some View {
    content
      .environment(\.seasonalAppearance, model.appearance)
      .environment(\.seasonalTestingReduceMotion, model.testingReduceMotion)
      .task(id: Schedule(active: phase == .active, revision: scheduleRevision)) {
        guard phase == .active else { return }
        // One cancellable sleep to calendar midnight; never background-poll the device.
        while !Task.isCancelled {
          model.refresh()
          guard let seconds = model.secondsUntilLocalMidnight else { return }
          do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh()
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
        refresh()
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
      ) { _ in refresh() }
  }

  private func refresh() {
    model.refresh()
    scheduleRevision &+= 1
  }
}
