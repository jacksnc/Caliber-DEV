import Foundation
import Testing

@testable import CaliberCore

@Test func widgetStoreRoundTripAndRevocation() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let store = NutritionWidgetSnapshotStore(directory: directory)
  #expect(store.read() == nil)
  let snapshot = NutritionWidgetSnapshot.daily(
    nutrition: .init(calories: 130, proteinGrams: 20, carbohydrateGrams: 6, fatGrams: 3), at: .now)
  try store.write(snapshot)
  #expect(store.read() == snapshot)
  #expect(
    try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
  try store.clear()
  #expect(store.read() == nil)
  try store.clear()
}

@Test func widgetStoreRejectsCorruptAndOversizedFiles() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let file = directory.appendingPathComponent("nutrition-widget-v1.json")
  let store = NutritionWidgetSnapshotStore(directory: directory)
  try Data("broken".utf8).write(to: file)
  #expect(store.read() == nil)
  try Data(repeating: 32, count: 8193).write(to: file)
  #expect(store.read() == nil)
}
