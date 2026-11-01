import XCTest

/// Uses only the existing fictional, in-memory showcase diary.
final class DiaryMealHeaderUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch(theme: String, largeText: Bool = false) -> XCUIApplication {
    XCUIDevice.shared.orientation = .portrait
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

  @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    let list = app.collectionViews.firstMatch
    for _ in 0..<18 {
      let tabBar = app.otherElements["caliberTabBar"]
      let top = list.frame.minY + 12
      let bottom = tabBar.exists ? tabBar.frame.minY - 8 : app.windows.firstMatch.frame.maxY - 24
      let visible =
        element.exists && element.isHittable
        && element.frame.minY >= top && element.frame.maxY <= bottom
      if visible { return }

      let moveContentDown =
        element.exists && !element.frame.isEmpty
        ? element.frame.minY < top : false
      let middle = top + max(24, bottom - top) / 2
      let delta = (moveContentDown ? 1.0 : -1.0) * min(130, max(30, (bottom - top) / 3))
      let origin = app.coordinate(withNormalizedOffset: .zero)
      origin.withOffset(CGVector(dx: list.frame.minX + 8, dy: middle)).press(
        forDuration: 0.05,
        thenDragTo: origin.withOffset(CGVector(dx: list.frame.minX + 8, dy: middle + delta)),
        withVelocity: .default, thenHoldForDuration: 0.1)
    }
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    XCTAssertTrue(element.isHittable, "Expected \(element) to be visible in the diary")
  }

  @MainActor private func assertHeader(
    _ meal: String, foodCount: String, calories: String, in app: XCUIApplication
  ) {
    let header = app.descendants(matching: .any)["diaryMealHeader-\(meal.lowercased())"].firstMatch
    reveal(header, in: app)
    XCTAssertTrue(header.label.localizedCaseInsensitiveContains(meal))
    XCTAssertTrue(header.label.contains(foodCount), "Unexpected summary: \(header.label)")
    XCTAssertTrue(header.label.contains("\(calories) cal"), "Unexpected summary: \(header.label)")

    for action in ["copy", "add"] {
      let button = app.buttons["diary\(action.capitalized)-\(meal.lowercased())"]
      reveal(button, in: app)
      XCTAssertGreaterThanOrEqual(button.frame.width, 47.5)
      XCTAssertGreaterThanOrEqual(button.frame.height, 47.5)
      XCTAssertTrue(button.isHittable)
    }
  }

  @MainActor func testCenteredMealHeadingsShowRecordedCountsAndKeepActions() {
    let app = launch(theme: "graphite")
    assertHeader("Breakfast", foodCount: "1 food", calories: "420", in: app)
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "Graphite centered Breakfast header"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    assertHeader("Lunch", foodCount: "1 food", calories: "650", in: app)
    assertHeader("Dinner", foodCount: "0 foods", calories: "0", in: app)
    assertHeader("Snack", foodCount: "1 food", calories: "392", in: app)
  }

  @MainActor func testMealHeadingAndLabeledActionsReflowAtAccessibilityTextSize() {
    let app = launch(theme: "frost", largeText: true)
    assertHeader("Breakfast", foodCount: "1 food", calories: "420", in: app)
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "Frost diary meal heading at accessibility text size"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  @MainActor func testNutritionSummaryChangesWithVisibleMetricControls() {
    let app = launch(theme: "graphite")
    let calories = app.staticTexts["diaryCalories"]
    XCTAssertEqual(calories.label, "1462 calories")
    calories.swipeLeft()
    XCTAssertTrue(app.staticTexts["diaryMetricValue-protein"].waitForExistence(timeout: 5))

    let protein = app.buttons["diaryMetric-protein"]
    reveal(protein, in: app)
    protein.tap()
    XCTAssertEqual(app.staticTexts["diaryMetricValue-protein"].label, "142 grams protein")

    let next = app.buttons["diaryNextMetric"]
    reveal(next, in: app)
    next.tap()
    XCTAssertEqual(
      app.staticTexts["diaryMetricValue-carbs"].label, "118 grams carbohydrates")

    let previous = app.buttons["diaryPreviousMetric"]
    reveal(previous, in: app)
    previous.tap()
    XCTAssertEqual(app.staticTexts["diaryMetricValue-protein"].label, "142 grams protein")
  }
}
