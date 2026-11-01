import Foundation

/// A tiny, replaceable cache. The caller supplies a shared directory, never a database URL.
public struct NutritionWidgetSnapshotStore: Sendable {
  public let directory: URL
  private var file: URL { directory.appendingPathComponent("nutrition-widget-v1.json") }

  public init(directory: URL) { self.directory = directory }

  /// Invalid, oversized or unreadable data fails closed. It never becomes zero intake.
  public func read() -> NutritionWidgetSnapshot? {
    guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      size <= 8192, let data = try? Data(contentsOf: file)
    else { return nil }
    return try? JSONDecoder().decode(NutritionWidgetSnapshot.self, from: data)
  }

  public func write(_ snapshot: NutritionWidgetSnapshot) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var excluded = directory
    var attributes = URLResourceValues()
    attributes.isExcludedFromBackup = true
    try excluded.setResourceValues(attributes)
    let data = try JSONEncoder().encode(snapshot)
    #if os(iOS)
      try data.write(to: file, options: [.atomic, .completeFileProtection])
    #else
      try data.write(to: file, options: .atomic)
    #endif
  }

  /// Revocation removes the only exported nutrition file. System-rendered timelines also
  /// need a reload request; iOS controls when it redraws an already displayed widget.
  public func clear() throws {
    if FileManager.default.fileExists(atPath: file.path) {
      try FileManager.default.removeItem(at: file)
    }
  }
}
