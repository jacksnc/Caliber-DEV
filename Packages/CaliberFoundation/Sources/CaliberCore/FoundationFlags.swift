import Foundation

/// A switch alone never bypasses consent, release eligibility or implementation readiness.
public struct FeatureFlag: Decodable, Sendable {
  public let id: String
  public let requirement: String
  public let `default`: Bool
}
public enum FeatureCatalog {
  private struct Document: Decodable { let flags: [FeatureFlag] }
  public static func bundled() throws -> [FeatureFlag] {
    guard let url = Bundle.module.url(forResource: "feature-flags", withExtension: "json") else {
      throw CatalogError.unavailable
    }
    return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).flags
  }
  public enum CatalogError: Error { case unavailable }
  public static func isEnabled(_ id: String) -> Bool {
    // No P1 feature has implementation/release clearance in Foundation.
    false
  }
}

/// Logging accepts only a closed vocabulary, never an Error, URL, dictionary or free-form health text.
public enum DiagnosticEvent: String, Codable, Sendable {
  case startupFailed, storageUnavailable, demoLoaded, syncFailed, authenticationFailed,
    migrationVerified
}
public enum SafeDiagnostics {
  public static func record(_ event: DiagnosticEvent, correlationID: UUID = UUID()) -> String {
    "event=\(event.rawValue) correlation=\(correlationID.uuidString.lowercased())"
  }
}

/// A v7 UUID encodes milliseconds; random bits break ties. It is not sync ordering authority.
public enum UUIDv7 {
  public static func make(date: Date = Date()) -> String {
    // Invalid dates must never trap during conversion to an unsigned integer.
    let rawMilliseconds = date.timeIntervalSince1970 * 1000
    let finiteMilliseconds = rawMilliseconds.isFinite ? rawMilliseconds : 0
    let milliseconds = UInt64(max(0, min(finiteMilliseconds, Double(0xFFFF_FFFF_FFFF))))
    let prefix = String(format: "%012llx", milliseconds)
    let random = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    return String(prefix.prefix(8)) + "-" + String(prefix.suffix(4)) + "-7"
      + String(random.prefix(3)) + "-8" + String(random.dropFirst(3).prefix(3)) + "-"
      + String(random.suffix(12))
  }
  public static func isValid(_ text: String) -> Bool {
    text.range(
      of: "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
      options: .regularExpression) != nil
  }
}
