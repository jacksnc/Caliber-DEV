import XCTest

/// Visual pass 2: Progress names the period of each group of cards and keeps an honest empty
/// timeline whose action still opens the real check-in form. Fictional in-memory store.
final class VisualPass2UITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
    // Rows below the floating dock are not tappable, so scroll until the element clears it.
    let dock = app.descendants(matching: .any)["caliberTabBar"]
    for _ in 0..<8 {
      let limit = dock.exists ? dock.frame.minY : app.frame.maxY
      if element.exists && element.isHittable && element.frame.maxY < limit { break }
      app.swipeUp()
    }
  }

  @MainActor func testEmptyProgressLabelsScopeAndOpensCheckIn() {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"]
    app.launch()
    let progress = app.tab("Progress")
    XCTAssertTrue(progress.waitForExistence(timeout: 20))
    progress.tap()

    let nutrition = app.descendants(matching: .any)["progressNutritionHeader"]
    reveal(nutrition, app: app)
    XCTAssertTrue(nutrition.label.contains("Last 7 days"), nutrition.label)

    let timeline = app.descendants(matching: .any)["progressTimelineHeader"]
    reveal(timeline, app: app)
    XCTAssertTrue(timeline.label.contains("No check-ins yet"), timeline.label)

    let add = app.buttons["progressEmptyAddCheckIn"]
    reveal(add, app: app)
    add.tap()
    XCTAssertTrue(app.buttons["progressSave"].waitForExistence(timeout: 5))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(add.waitForExistence(timeout: 5))
  }
}
