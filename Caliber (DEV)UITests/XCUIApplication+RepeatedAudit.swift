import XCTest

extension XCUIApplication {
  /// Runs the system accessibility audit twice and fails only the issues reported both
  /// times (D113). At AX5 the "Dynamic Type partially unsupported" check has flagged
  /// different, unchanged screens on different CI runs; a real problem repeats. Every
  /// issue from both passes is printed with its element, so nothing is hidden from the log.
  @MainActor func auditRepeatedIssues(for types: XCUIAccessibilityAuditType) throws {
    var first = Set<String>()
    try auditOnce(for: types) { issue in
      first.insert(Self.auditKey(issue))
      print("ACCESSIBILITY (pass 1): \(issue.compactDescription): \(issue.detailedDescription)")
      if let element = issue.element { print(element.debugDescription) }
      return true
    }
    guard !first.isEmpty else { return }
    try auditOnce(for: types) { issue in
      let repeated = first.contains(Self.auditKey(issue))
      print(
        "ACCESSIBILITY (pass 2, \(repeated ? "repeated" : "not repeated")): "
          + "\(issue.compactDescription): \(issue.detailedDescription)")
      if let element = issue.element { print(element.debugDescription) }
      return !repeated
    }
  }

  /// A pass that times out on a heavy screen runs once more; issues are never skipped.
  @MainActor private func auditOnce(
    for types: XCUIAccessibilityAuditType,
    _ handler: @escaping (XCUIAccessibilityAuditIssue) throws -> Bool
  ) throws {
    do {
      try performAccessibilityAudit(for: types, handler)
    } catch let error as NSError
      where error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56
    {
      try performAccessibilityAudit(for: types, handler)
    }
  }

  private static func auditKey(_ issue: XCUIAccessibilityAuditIssue) -> String {
    let element = issue.element
    return [
      String(issue.auditType.rawValue), issue.compactDescription,
      element?.identifier ?? "", element?.label ?? "",
    ].joined(separator: "|")
  }
}
