import CaliberCore
import SwiftUI
import WidgetKit

struct NutritionWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: NutritionWidgetSnapshot
}

struct NutritionWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> NutritionWidgetEntry {
    .init(date: .now, snapshot: .privateSnapshot(at: .now))
  }

  func getSnapshot(in context: Context, completion: @escaping (NutritionWidgetEntry) -> Void) {
    completion(entry(at: .now))
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<NutritionWidgetEntry>) -> Void
  ) {
    let now = Date.now
    let current = entry(at: now)
    if current.snapshot.displayState(at: now) == .current {
      // A second entry removes old figures at expiry even when the app stays closed.
      let expires = current.snapshot.expiresAt
      completion(
        Timeline(
          entries: [current, .init(date: expires, snapshot: current.snapshot)], policy: .never))
    } else {
      // Save/consent events request reloads. Do not continuously poll private data.
      completion(Timeline(entries: [current], policy: .never))
    }
  }

  private func entry(at now: Date) -> NutritionWidgetEntry {
    let directory = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.CAL.Caliber-DEV.widgets")
    let snapshot =
      directory.flatMap { NutritionWidgetSnapshotStore(directory: $0).read() }
      ?? .privateSnapshot(at: now)
    return .init(date: now, snapshot: snapshot)
  }
}

@main
struct CaliberNutritionWidget: Widget {
  let kind = "CaliberNutritionWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: NutritionWidgetProvider()) { entry in
      NutritionWidgetView(snapshot: entry.snapshot, now: entry.date)
    }
    .configurationDisplayName("Daily Nutrition")
    .description("Open Fuel or show the daily totals you choose to share in Caliber Settings.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
