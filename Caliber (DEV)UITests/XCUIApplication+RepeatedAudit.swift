import XCTest

extension XCUIApplication {
  /// Runs the system accessibility audit twice and fails only the issues reported both
  /// times (D113). At AX5 the "Dynamic Type partially unsupported" check has flagged
  /// different, unchanged screens on different CI runs; a real problem repeats. Every
  /// issue from both passes is printed with its element, so nothing is hidden from the log.
  @MainActor func auditRepeatedIssues(for types: XCUIAccessibilityAuditType) throws {
    var first = Set<String>()
    try performAccessibilityAudit(for: types) { issue in
      first.insert(Self.auditKey(issue))
      print("ACCESSIBILITY (pass 1): \(issue.compactDescription): \(issue.detailedDescription)")
      if let element = issue.element { print(element.debugDescription) }
      return true
    }
    guard !first.isEmpty else { return }
    try performAccessibilityAudit(for: types) { issue in
      let repeated = first.contains(Self.auditKey(issue))
      print(
        "ACCESSIBILITY (pass 2, \(repeated ? "repeated" : "not repeated")): "
          + "\(issue.compactDescription): \(issue.detailedDescription)")
      if let element = issue.element { print(element.debugDescription) }
      return !repeated
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
