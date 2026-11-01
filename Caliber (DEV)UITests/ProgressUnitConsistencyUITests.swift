import XCTest

final class ProgressUnitConsistencyUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--theme-frost"]
    app.launch()
    XCTAssertTrue(app.tab("Progress").waitForExistence(timeout: 20))
    app.tab("Progress").tap()
    return app
  }

  @MainActor private func reveal(
    _ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false
  ) {
    for _ in 0..<18 where !element.isHittable {
      let start: CGFloat = towardTop ? 0.45 : 0.72
      let end: CGFloat = towardTop ? 0.72 : 0.45
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start)).press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end)))
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor func testSavedUnitMatchesTodayAndSurvivesUnrelatedSettingsSave() {
    let app = launch()
    app.buttons["addProgressEntry"].tap()
    let weight = app.textFields["progressWeight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    app.segmentedControls.buttons["kg"].tap()
    weight.tap()
    weight.typeText("80")
    app.buttons["progressSave"].tap()
    let latest = app.staticTexts["latestProgressWeight"]
    XCTAssertTrue(latest.waitForExistence(timeout: 5))
    XCTAssertTrue(latest.label.contains("kg"), latest.label)
    app.tab("Today").tap()
    let tile = app.descendants(matching: .any)["todayWeightTile"].firstMatch
    XCTAssertTrue(tile.waitForExistence(timeout: 5))
    XCTAssertTrue(tile.label.contains("kg"), tile.label)
    app.openSettings()
    let graphite = app.buttons["appearanceTheme-dark"]
    reveal(graphite, in: app, towardTop: true)
    graphite.tap()
    app.leaveProfile()
    app.tab("Progress").tap()
    XCTAssertTrue(latest.label.contains("kg"), latest.label)
    app.terminate()
    app.launchArguments = ["--foundation-ui-testing", "--theme-frost"]
    app.launch()
    XCTAssertTrue(app.tab("Progress").waitForExistence(timeout: 10))
    app.tab("Progress").tap()
    app.buttons["addProgressEntry"].tap()
    XCTAssertTrue(app.textFields["progressWeight"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.segmentedControls.buttons["kg"].isSelected)
  }

  @MainActor func testCancelDoesNotChangeThePreferredUnit() {
    let app = launch()
    app.buttons["addProgressEntry"].tap()
    XCTAssertTrue(app.textFields["progressWeight"].waitForExistence(timeout: 5))
    app.segmentedControls.buttons["kg"].tap()
    app.buttons["Cancel"].tap()
    app.buttons["addProgressEntry"].tap()
    XCTAssertTrue(app.textFields["progressWeight"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.segmentedControls.buttons["lb"].isSelected)
  }
}
