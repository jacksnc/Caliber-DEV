import CaliberCore
import SwiftData
import SwiftUI

#if canImport(WidgetKit)
  import WidgetKit
#endif

/// No app database is exposed to the extension. Only an explicitly enabled daily cache is shared.
struct NutritionWidgetPublisher: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var phase
  @AppStorage("widgets.shareNutrition.v1") private var sharesNutrition = false
  @State private var lastSnapshot: NutritionWidgetSnapshot?

  var body: some View {
    Color.clear.frame(width: 0, height: 0).accessibilityHidden(true)
      .onAppear(perform: publish)
      .onChange(of: sharesNutrition) { _, _ in publish() }
      .onChange(of: runtime.settings.hideNumbers) { _, _ in publish() }
      .onChange(of: runtime.isDemoMode) { _, _ in publish() }
      .onChange(of: phase) { _, value in if value == .active { publish() } }
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in publish()
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
        publish()
      }
      .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
        // Let SwiftData finish its successful-save notification before checking hasChanges.
        Task { @MainActor in
          await Task.yield()
          publish()
        }
      }
  }

  private func publish() {
    let directory: URL?
    if runtime.testing {
      directory = FileManager.default.temporaryDirectory.appendingPathComponent("CaliberWidgetQA")
    } else {
      directory = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.CAL.Caliber-DEV.widgets")
    }
    guard let directory else { return }
    let store = NutritionWidgetSnapshotStore(directory: directory)
    guard sharesNutrition, !runtime.settings.hideNumbers, !runtime.isDemoMode else {
      do {
        try store.clear()
        lastSnapshot = nil
        reload()
      } catch {
        runtime.message =
          "Could not remove widget data. Please try turning widget sharing off again."
      }
      return
    }
    // A successful save triggers another attempt. Never export a partially edited form.
    guard !context.hasChanges else { return }
    do {
      let now = Date.now
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .current
      let start = calendar.startOfDay(for: now)
      guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
      let descriptor = FetchDescriptor<DiaryEntry>(
        predicate: #Predicate { $0.date >= start && $0.date < end })
      let totals = MacroCalculator.totals(for: try context.fetch(descriptor))
      let values = NutritionWidgetValues(
        calories: totals.calories, proteinGrams: totals.protein,
        carbohydrateGrams: totals.carbs, fatGrams: totals.fat)
      // Avoid consuming reload budget on unrelated saves while the same cache is fresh.
      if lastSnapshot?.nutrition == values,
        lastSnapshot?.displayState(at: now) == .current
      {
        return
      }
      let snapshot = NutritionWidgetSnapshot.daily(nutrition: values, at: now)
      guard snapshot.displayState(at: now) == .current else {
        try store.clear()
        lastSnapshot = nil
        reload()
        return
      }
      try store.write(snapshot)
      lastSnapshot = snapshot
      reload()
    } catch {
      try? store.clear()
      lastSnapshot = nil
      reload()
      runtime.message = "Could not refresh widget data. Open Caliber to try again."
    }
  }

  private func reload() {
    #if canImport(WidgetKit)
      WidgetCenter.shared.reloadTimelines(ofKind: "CaliberNutritionWidget")
    #endif
  }
}
