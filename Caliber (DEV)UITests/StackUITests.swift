import XCTest

/// Stack stays hidden until the person opts in, then logs a dose they entered themselves.
final class StackUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor func testOptInAddCompoundAndLogDose() {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"]
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    XCTAssertFalse(app.tab("Stack").exists)

    app.openSettings()
    let module = app.switches["stackModuleToggle"]
    for _ in 0..<6 where !module.isHittable { app.swipeUp() }
    module.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    let scope = app.switches["stackScopeConfirmation"]
    XCTAssertTrue(scope.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["stackTurnOn"].isEnabled)
    scope.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    app.buttons["stackTurnOn"].tap()
    XCTAssertTrue(app.switches["stackLockToggle"].waitForExistence(timeout: 5))
    app.leaveProfile()

    let stack = app.tab("Stack")
    XCTAssertTrue(stack.waitForExistence(timeout: 5))
    stack.tap()
    let addFirst = app.buttons["stackAddFirst"]
    XCTAssertTrue(addFirst.waitForExistence(timeout: 10))
    addFirst.tap()
    let name = app.textFields["stackName"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("Test compound")
    let amount = app.textFields["stackAmount"]
    amount.tap()
    amount.typeText("0.25")
    app.buttons["stackSave"].tap()

    // Scheduled daily at the current minute, so it is due now.
    let log = app.buttons["stackLogDose"]
    XCTAssertTrue(log.waitForExistence(timeout: 5))
    log.tap()
    let logAmount = app.textFields["stackLogAmount"]
    XCTAssertTrue(logAmount.waitForExistence(timeout: 5))
    XCTAssertEqual(logAmount.value as? String, "0.25")
    app.buttons["stackLogSave"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Taken"))
        .firstMatch.waitForExistence(timeout: 5))
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "stack-after-logging"
    picture.lifetime = .keepAlways
    add(picture)
  }
}
