import XCTest

final class WidgetSettingsUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor func testNutritionSharingIsOffByDefaultAndPersistsOnlyExplicitChoice() {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--theme-frost"]
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    app.openSettings()
    let sharing = app.switches["shareWidgetNutrition"]
    for _ in 0..<6 where !sharing.isHittable { app.swipeUp() }
    XCTAssertTrue(sharing.isHittable)
    XCTAssertEqual(sharing.value as? String, "0")
    sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    XCTAssertEqual(sharing.value as? String, "1")
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Frost widget sharing is an explicit choice"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.terminate()
    app.launchArguments = ["--foundation-ui-testing", "--theme-frost"]
    app.launch()
    // Progress fixture bypasses welcome only for that launch; confirm it normally on relaunch.
    let proceed = app.buttons["welcomeContinue"]
    if proceed.waitForExistence(timeout: 3) {
      for name in ["adultConfirmation", "scopeConfirmation"] {
        app.switches[name].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
      }
      proceed.tap()
    }
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    app.openSettings()
    for _ in 0..<6 where !sharing.isHittable { app.swipeUp() }
    XCTAssertEqual(sharing.value as? String, "1")
    sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    XCTAssertEqual(sharing.value as? String, "0")
  }
}
