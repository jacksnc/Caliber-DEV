import XCTest

/// The Today nutrition card pages through Calories, Protein, Carbs and Fat. Uses only the
/// fictional in-memory showcase store: 1,462 kcal · 142 g protein · 118 g carbs · 52 g fat
/// logged today, against saved goals of 2,350 kcal · 180 g · 240 g · 70 g.
final class TodayInfoCardPagerUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch(textSize: String? = nil) -> XCUIApplication {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--showcase-fixture", "--theme-frost"]
    if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    app.tab("Today").tap()
    return app
  }

  @MainActor private func panel(_ app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)["todayFuel-panel"].firstMatch
  }

  /// Waits for the panel to report the page, then checks the value it shows.
  @MainActor private func assertPage(
    _ name: String, _ number: Int, shows value: String, app: XCUIApplication,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let panel = panel(app)
    let position = NSPredicate(format: "value CONTAINS %@", "\(name), page \(number) of 4")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: position, object: panel)], timeout: 5),
      .completed, "Expected \(name) page", file: file, line: line)
    XCTAssertTrue(panel.label.contains(value), "\(panel.label)", file: file, line: line)
    let tab = app.buttons["todayFuel-page-\(name.lowercased())"]
    XCTAssertTrue(tab.isSelected, file: file, line: line)
  }

  @MainActor private func assertTarget(
    _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertTrue(element.exists, file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.width, 47.5, file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.height, 47.5, file: file, line: line)
  }

  @MainActor func testFuelCardPagesByButtonNameAndSwipeWithoutAutoplay() {
    let app = launch()
    let panel = panel(app)
    XCTAssertTrue(panel.waitForExistence(timeout: 10))
    // Calories left from the saved goal: 2,350 − 1,462 = 888 (Left is the default mode).
    assertPage("Calories", 1, shows: "888", app: app)

    let next = app.buttons["todayFuel-next"]
    let previous = app.buttons["todayFuel-previous"]
    for control in [
      next, previous, app.buttons["todayFuel-page-calories"], app.buttons["todayFuel-page-protein"],
      app.buttons["todayFuel-page-carbs"], app.buttons["todayFuel-page-fat"],
    ] { assertTarget(control) }
    XCTAssertTrue(app.buttons["todayFuel-page-protein"].label.contains("142"))

    next.tap()
    assertPage("Protein", 2, shows: "38", app: app)
    app.buttons["todayFuel-page-fat"].tap()
    assertPage("Fat", 4, shows: "18", app: app)
    previous.tap()
    assertPage("Carbs", 3, shows: "122", app: app)

    // Horizontal swipes on the value panel page and wrap; nothing advances by itself.
    panel.swipeLeft()
    assertPage("Fat", 4, shows: "18", app: app)
    panel.swipeLeft()
    assertPage("Calories", 1, shows: "888", app: app)
    panel.swipeRight()
    assertPage("Fat", 4, shows: "18", app: app)
    let changed = NSPredicate(format: "NOT (value CONTAINS %@)", "Fat, page 4 of 4")
    let mustNotChange = XCTNSPredicateExpectation(predicate: changed, object: panel)
    mustNotChange.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [mustNotChange], timeout: 3), .completed)
    assertPage("Fat", 4, shows: "18", app: app)

    // A vertical drag on the panel scrolls the screen instead of paging.
    panel.swipeUp()
    assertPage("Fat", 4, shows: "18", app: app)

    // The other Today actions are still there.
    XCTAssertTrue(app.buttons["todayStartWorkout"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["openDemo"].exists)
  }

  @MainActor func testFuelCardTabsStackAndStayFullSizeAtAccessibilityText() {
    let app = launch(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
    XCTAssertTrue(panel(app).waitForExistence(timeout: 10))
    let tabs = ["calories", "protein", "carbs", "fat"].map { app.buttons["todayFuel-page-\($0)"] }
    for tab in tabs { assertTarget(tab) }
    // One column at AX sizes: each tab starts below the previous one.
    for (upper, lower) in zip(tabs, tabs.dropFirst()) {
      XCTAssertLessThanOrEqual(upper.frame.maxY, lower.frame.minY + 1)
    }
    assertTarget(app.buttons["todayFuel-next"])
    tabs[1].tap()
    assertPage("Protein", 2, shows: "38", app: app)
  }
}
