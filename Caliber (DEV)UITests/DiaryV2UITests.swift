import XCTest

/// Uses only the existing fictional in-memory store. Never launches a personal store.
final class DiaryV2UITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch(theme: String, largeText: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--showcase-fixture", "--theme-\(theme)"]
    if largeText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    XCTAssertTrue(app.tab("Fuel").waitForExistence(timeout: 20))
    app.tab("Fuel").tap()
    return app
  }

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor private func reveal(
    _ element: XCUIElement, app: XCUIApplication, towardTop: Bool = false
  ) {
    for _ in 0..<18 {
      let top =
        app.navigationBars.firstMatch.exists
        ? app.navigationBars.firstMatch.frame.maxY + 8 : 72
      let bottom =
        app.otherElements["caliberTabBar"].exists
        ? app.otherElements["caliberTabBar"].frame.minY - 8 : app.windows.firstMatch.frame.maxY - 24
      let hasFrame = element.exists && element.frame.width > 0 && element.frame.height > 0
      if hasFrame && element.isHittable && element.frame.minY >= top && element.frame.maxY <= bottom
      {
        return
      }
      let down = hasFrame ? element.frame.minY < top : towardTop
      let middle = top + max(20, bottom - top) / 2
      let delta = (down ? 1.0 : -1.0) * min(120, max(20, bottom - top) / 3)
      let origin = app.coordinate(withNormalizedOffset: .zero)
      origin.withOffset(CGVector(dx: 12, dy: middle)).press(
        forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 12, dy: middle + delta)))
    }
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    XCTAssertTrue(element.isHittable)
    XCTAssertLessThanOrEqual(element.frame.maxY, app.otherElements["caliberTabBar"].frame.minY - 8)
  }

  @MainActor private func inspect(theme: String, largeText: Bool = false) throws {
    let app = launch(theme: theme, largeText: largeText)
    let calories = app.staticTexts["diaryCalories"]
    reveal(calories, app: app)
    XCTAssertEqual(calories.label, "1462 calories")
    let balance = app.descendants(matching: .any)["diaryEnergyBalance"].firstMatch
    XCTAssertTrue(balance.waitForExistence(timeout: 5))
    capture("v2-\(theme)-Diary-\(largeText ? "AX5" : "default")", app: app)
    try app.auditRepeatedIssues(for: largeText ? [.dynamicType, .textClipped] : [.textClipped])

    let add = app.buttons["diaryAdd-breakfast"]
    reveal(add, app: app)
    XCTAssertGreaterThanOrEqual(add.frame.width, 47.5)
    XCTAssertGreaterThanOrEqual(add.frame.height, 47.5)
    add.tap()
    let context = app.staticTexts["foodEntryContextSummary"]
    XCTAssertTrue(context.waitForExistence(timeout: 10))
    XCTAssertTrue(context.label.contains("Breakfast"))
  }

  @MainActor func testGraphiteDiarySummaryAndMealRoute() throws { try inspect(theme: "graphite") }
  @MainActor func testFrostDiarySummaryAndMealRoute() throws { try inspect(theme: "frost") }
  @MainActor func testLargestTextDiaryReflowsAndKeepsMealActions() throws {
    try inspect(theme: "frost", largeText: true)
  }

  @MainActor func testNextDayIsEmptyAndReturningRestoresTheRecordedTotal() {
    let app = launch(theme: "graphite")
    app.buttons["diaryNextDay"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "0 calories")
    app.buttons["diaryPreviousDay"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "1462 calories")
  }
}
