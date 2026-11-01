import XCTest

final class HealthEnergyUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<16 where !element.isHittable {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.51)))
    }
    if !element.isHittable {
      let detail = XCTAttachment(string: app.debugDescription)
      detail.name = "Health setup element discovery"
      detail.lifetime = .keepAlways
      add(detail)
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor func testExplicitHealthSetupAdjustsTodayWithoutChangingTheSavedBaseGoal() {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--showcase-fixture", "--theme-frost"]
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    app.openSettings()
    let health = app.buttons["openActiveEnergySettings"]
    reveal(health, in: app)
    health.tap()
    let connect = app.buttons["connectActiveEnergy"]
    XCTAssertTrue(connect.waitForExistence(timeout: 10))
    connect.tap()  // Isolated fixture; no real Health permissions or records.
    XCTAssertTrue(app.staticTexts["healthActiveEnergy"].waitForExistence(timeout: 10))
    let allowance = app.textFields["healthActivityAllowance"]
    reveal(allowance, in: app)
    allowance.tap()
    allowance.typeText("300")
    app.buttons["healthAllowanceDone"].tap()
    let confirmation = app.switches["confirmActivityAllowance"]
    reveal(confirmation, in: app)
    confirmation.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    let save = app.buttons["saveActivityAllowance"]
    reveal(save, in: app)
    save.tap()
    XCTAssertTrue(app.staticTexts["confirmedActivityAllowance"].waitForExistence(timeout: 5))
    let adjustment = app.switches["adjustGoalFromHealth"]
    reveal(adjustment, in: app)
    XCTAssertTrue(adjustment.isEnabled)
    adjustment.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.leaveProfile()
    let panel = app.descendants(matching: .any)["todayFuel-panel"].firstMatch
    XCTAssertTrue(panel.waitForExistence(timeout: 10))
    XCTAssertTrue(panel.label.contains("2,500"), panel.label)
    XCTAssertTrue(panel.label.contains("1,038"), panel.label)
    let breakdown = app.descendants(matching: .any)["healthGoalBreakdown"].firstMatch
    for _ in 0..<8 where !breakdown.isHittable { app.swipeUp() }
    XCTAssertTrue(breakdown.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Today's goal: 2,500 kcal"].exists)
    XCTAssertTrue(app.staticTexts["Base goal: 2,350 kcal"].exists)
    XCTAssertTrue(app.staticTexts["Health adjustment: +150 kcal"].exists)
    reveal(app.staticTexts["Today's goal: 2,500 kcal"], in: app)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).press(
      forDuration: 0.05,
      thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58)))
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Health fixture base plus confirmed-allowance adjustment"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    // The current diary uses the same adjustment; past days still show the saved base goal.
    app.tab("Fuel").tap()
    let adjustedDiaryGoal = app.staticTexts["of 2500 calories"]
    XCTAssertTrue(adjustedDiaryGoal.waitForExistence(timeout: 10))
    let previousDay = app.buttons["diaryPreviousDay"]
    for _ in 0..<6 where !previousDay.isHittable { app.swipeDown() }
    previousDay.tap()
    XCTAssertTrue(app.staticTexts["of 2350 calories"].waitForExistence(timeout: 5))
    XCTAssertFalse(adjustedDiaryGoal.exists)
    app.buttons["diaryNextDay"].tap()
    XCTAssertTrue(adjustedDiaryGoal.waitForExistence(timeout: 5))
  }
}
