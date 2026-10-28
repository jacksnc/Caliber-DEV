import CaliberCore
import SwiftData
import SwiftUI

/// Existing profiles keep their current targets. New users can skip setup and
/// still use the diary; Profile always provides a way to return to the wizard.
struct GoalSetupHostView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Query private var profiles: [UserProfile]
  @State private var showsSetup = false

  var body: some View {
    RootTabView()
      .sheet(isPresented: $showsSetup) {
        GoalSetupView(
          profile: profiles.first, mass: runtime.settings.massUnit,
          length: runtime.settings.distanceUnit)
      }
      .task {
        // Normal test suites keep their existing launch route. A dedicated flag
        // exercises first-run setup in an isolated in-memory store.
        let testRequested =
          runtime.testing
          && ProcessInfo.processInfo.arguments.contains("--goal-setup-first-run")
        guard !runtime.testing || testRequested,
          runtime.completedWelcomeThisSession || testRequested,
          !runtime.preferenceStore.bool(forKey: "goalSetupPromptSeen.v1"),
          profiles.isEmpty, !runtime.settings.hideNumbers
        else { return }
        // Use the same preference store as the runtime (isolated during tests).
        runtime.preferenceStore.set(true, forKey: "goalSetupPromptSeen.v1")
        showsSetup = true
      }
  }
}
