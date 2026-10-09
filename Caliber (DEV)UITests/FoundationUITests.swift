import XCTest

final class FoundationUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--foundation-ui-testing", "--reset-foundation"]
    app.launch()
    let proceed = app.buttons["welcomeContinue"]
    XCTAssertTrue(proceed.waitForExistence(timeout: 20))
    XCTAssertFalse(proceed.isEnabled)
    app.switches["adultConfirmation"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
      .tap()
    XCTAssertEqual(app.switches["adultConfirmation"].value as? String, "1")
    app.switches["scopeConfirmation"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
      .tap()
    XCTAssertEqual(app.switches["scopeConfirmation"].value as? String, "1")
    XCTAssertTrue(proceed.isEnabled)
    proceed.tap()
    XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    return app
  }
  @MainActor func testDemoAndExitPreserveEmptyPersonalDiary() {
    let app = launch()
    app.buttons["openDemo"].tap()
    XCTAssertTrue(app.buttons["exitDemo"].waitForExistence(timeout: 30))
    XCTAssertTrue(app.staticTexts["Body weight"].waitForExistence(timeout: 10))
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "Foundation demo chart"
    picture.lifetime = .keepAlways
    add(picture)
    app.buttons["View data table"].firstMatch.tap()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", "Not logged")
      ).firstMatch.waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.buttons["exitDemo"].tap()
    XCTAssertTrue(app.staticTexts["No food logged today"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Food Library"].tap()
    XCTAssertTrue(app.buttons["Restaurants"].waitForExistence(timeout: 10))
  }
  @MainActor func testNumberHidingRemovesNumericRoutesAndAllowsNotes() {
    let app = launch()
    app.tabBars.buttons["Settings"].tap()
    app.switches["hideNumbers"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    XCTAssertTrue(app.navigationBars["Your Journal"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.tabBars.buttons["Diary"].exists)
    app.buttons["Add a Photo or Note"].tap()
    XCTAssertTrue(app.textViews["progressNotes"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.textFields["progressWeight"].exists)
    app.textViews["progressNotes"].tap()
    app.textViews["progressNotes"].typeText("A calm day")
    app.buttons["progressSave"].tap()
    XCTAssertTrue(app.staticTexts["A calm day"].waitForExistence(timeout: 5))
    app.terminate()
    app.launchArguments = ["--foundation-ui-testing"]
    app.launch()
    XCTAssertTrue(app.navigationBars["Your Journal"].waitForExistence(timeout: 10))
  }
}
