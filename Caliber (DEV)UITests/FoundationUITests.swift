import XCTest

final class FoundationUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  @MainActor private func launch(additionalArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--foundation-ui-testing", "--reset-foundation"] + additionalArguments
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
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 10))
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
    app.buttons["chartTable-Body weight"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", "Not logged")
      ).firstMatch.waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.buttons["exitDemo"].tap()
    XCTAssertTrue(app.staticTexts["No food logged today"].waitForExistence(timeout: 10))
    app.openFoodLibrary()
    XCTAssertTrue(app.buttons["Restaurants"].waitForExistence(timeout: 10))
  }
  @MainActor func testNumberHidingRemovesNumericRoutesAndAllowsNotes() {
    let app = launch()
    app.openSettings()
    app.switches["hideNumbers"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    XCTAssertTrue(app.navigationBars["Your Journal"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.tab("Fuel").exists)
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
  @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<8 {
      if element.isHittable { return }
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor func testSelectedDecimalFormatSurvivesProgressSaveAndCancel() {
    let app = launch()
    app.openSettings()
    let format = app.buttons["settingsNumberFormat"]
    reveal(format, in: app)
    format.tap()
    // The menu does not open if the tap lands while Settings is still sliding in.
    let german = app.buttons["German (Germany)"]
    for _ in 0..<3 where !german.waitForExistence(timeout: 2) { format.tap() }
    german.tap()
    app.leaveProfile()
    app.tab("Progress").tap()
    app.buttons["addProgressEntry"].tap()
    let weight = app.textFields["progressWeight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    weight.tap()
    weight.typeText("180,5")
    XCTAssertTrue(app.buttons["progressSave"].isEnabled)
    app.buttons["progressSave"].tap()
    app.buttons["addProgressEntry"].tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "180,5")
    weight.focusAtEnd()
    weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "175,25")
    app.buttons["Cancel"].tap()
    app.buttons["addProgressEntry"].tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "180,5")
  }

  @MainActor func testAccountSignInAndDeviceSignOutUseOnlyFixture() {
    let app = launch(additionalArguments: ["--account-ui-testing"])
    app.openSettings()
    let open = app.buttons["openAccount"]
    reveal(open, in: app)
    app.tap(open, until: app.switches["accountConsent"])
    XCTAssertFalse(app.buttons["accountConsentContinue"].isEnabled)
    app.switches["accountConsent"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
      .tap()
    app.buttons["accountConsentContinue"].tap()
    let email = app.textFields["accountEmail"]
    XCTAssertTrue(email.waitForExistence(timeout: 5))
    email.tap()
    email.typeText("fixture@example.invalid")
    app.secureTextFields["accountPassword"].tap()
    app.secureTextFields["accountPassword"].typeText("fixture-password")
    app.buttons["accountSignIn"].tap()
    XCTAssertTrue(app.staticTexts["accountSignedIn"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["accountMessage"].label.contains("cloud backup is not active"))
    app.buttons["accountSignOut"].tap()
    XCTAssertTrue(email.waitForExistence(timeout: 5))
    XCTAssertEqual(app.secureTextFields["accountPassword"].value as? String, "Password")
    XCTAssertEqual(app.staticTexts["accountMessage"].label, "Signed out on this device.")
  }

  /// Every issue is printed with its element, so CI logs say what failed; none is suppressed.
  @MainActor private func audit(_ app: XCUIApplication) throws {
    try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion]) { issue in
      print("ACCESSIBILITY: \(issue.compactDescription): \(issue.detailedDescription)")
      if let element = issue.element { print(element.debugDescription) }
      return false
    }
  }

  @MainActor func testDemoAtLargestTextSizeHasUsableChartRoutes() throws {
    let app = launch()
    app.terminate()
    app.launchArguments = [
      "--foundation-ui-testing", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    app.launch()
    let demo = app.buttons["openDemo"]
    reveal(demo, in: app)
    demo.tap()
    let table = app.buttons["chartTable-Body weight"]
    XCTAssertTrue(app.buttons["exitDemo"].waitForExistence(timeout: 30))
    reveal(table, in: app)
    XCTAssertGreaterThanOrEqual(table.frame.height, 48)
    try audit(app)
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "Foundation demo AX5"
    picture.lifetime = .keepAlways
    add(picture)
    table.tap()
    XCTAssertTrue(app.navigationBars["Body weight"].waitForExistence(timeout: 5))
    try audit(app)
    let tablePicture = XCTAttachment(screenshot: app.screenshot())
    tablePicture.name = "Foundation data table AX5"
    tablePicture.lifetime = .keepAlways
    add(tablePicture)
    app.navigationBars.buttons.element(boundBy: 0).tap()

    let info = app.buttons["chartInfo-Body weight"]
    for _ in 0..<8 {
      if info.isHittable { break }
      app.swipeDown()
    }
    XCTAssertTrue(info.isHittable)
    XCTAssertGreaterThanOrEqual(info.frame.width, 48)
    XCTAssertGreaterThanOrEqual(info.frame.height, 48)
    info.tap()
    XCTAssertTrue(app.navigationBars["Method"].waitForExistence(timeout: 5))
    try audit(app)
    let methodPicture = XCTAttachment(screenshot: app.screenshot())
    methodPicture.name = "Foundation calculation method AX5"
    methodPicture.lifetime = .keepAlways
    add(methodPicture)
    app.buttons["exitDemo"].tap()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 5))
  }

  @MainActor private func openFixtureAccount(in app: XCUIApplication) {
    app.openSettings()
    let open = app.buttons["openAccount"]
    reveal(open, in: app)
    let consent = app.switches["accountConsent"]
    app.tap(open, until: consent)
    consent.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    app.buttons["accountConsentContinue"].tap()
    XCTAssertTrue(app.textFields["accountEmail"].waitForExistence(timeout: 5))
  }
  @MainActor func testRecoveryUsesCodeWithoutSigningIn() {
    let app = launch(additionalArguments: ["--account-ui-testing"])
    openFixtureAccount(in: app)
    app.buttons["accountRecover"].tap()
    let email = app.textFields["recoveryEmail"]
    XCTAssertTrue(email.waitForExistence(timeout: 5))
    email.tap()
    email.typeText("fixture@example.invalid")
    app.buttons["recoverySend"].tap()
    XCTAssertTrue(app.staticTexts["recoveryMessage"].waitForExistence(timeout: 5))
    app.textFields["recoveryCode"].tap()
    app.textFields["recoveryCode"].typeText("123456")
    app.secureTextFields["recoveryNewPassword"].tap()
    app.secureTextFields["recoveryNewPassword"].typeText("new-fixture-password")
    app.secureTextFields["recoveryRepeatPassword"].tap()
    app.secureTextFields["recoveryRepeatPassword"].typeText("new-fixture-password")
    let submit = app.buttons["recoveryChangePassword"]
    reveal(submit, in: app)
    XCTAssertTrue(submit.isEnabled)
    submit.tap()
    XCTAssertTrue(app.staticTexts["recoveryMessage"].waitForExistence(timeout: 5))
    XCTAssertEqual(
      app.staticTexts["recoveryMessage"].label, "Password changed. Sign in with your new password.")
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "Password recovery fixture"
    picture.lifetime = .keepAlways
    add(picture)
    app.buttons["Done"].tap()
    XCTAssertTrue(app.textFields["accountEmail"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["accountSignedIn"].exists)
  }
  @MainActor func testHostedDeletionKeepsLocalProgressNote() {
    let app = launch(additionalArguments: ["--account-ui-testing"])
    app.tab("Progress").tap()
    app.buttons["addProgressEntry"].tap()
    let notes = app.textViews["progressNotes"]
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    notes.tap()
    notes.typeText("Kept after hosted deletion")
    app.buttons["progressSave"].tap()
    openFixtureAccount(in: app)
    app.textFields["accountEmail"].tap()
    app.textFields["accountEmail"].typeText("fixture@example.invalid")
    app.secureTextFields["accountPassword"].tap()
    app.secureTextFields["accountPassword"].typeText("fixture-password")
    app.buttons["accountSignIn"].tap()
    XCTAssertTrue(app.staticTexts["accountSignedIn"].waitForExistence(timeout: 5))
    app.buttons["accountDelete"].tap()
    XCTAssertTrue(app.secureTextFields["deletionPassword"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["deletionSubmit"].isEnabled)
    app.secureTextFields["deletionPassword"].tap()
    app.secureTextFields["deletionPassword"].typeText("fixture-password")
    app.textFields["deletionConfirmation"].tap()
    app.textFields["deletionConfirmation"].typeText("DELETE")
    reveal(app.buttons["deletionSubmit"], in: app)
    app.buttons["deletionSubmit"].tap()
    app.buttons["Permanently Delete Account"].tap()
    XCTAssertTrue(app.switches["accountConsent"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.switches["accountConsent"].value as? String, "0")
    XCTAssertFalse(app.buttons["accountConsentContinue"].isEnabled)
    XCTAssertTrue(
      app.staticTexts["accountMessage"].label.contains("Your local logs and photos are still here"))
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "Hosted deletion fixture"
    picture.lifetime = .keepAlways
    add(picture)
    app.leaveProfile()
    app.tab("Progress").tap()
    XCTAssertTrue(app.staticTexts["Kept after hosted deletion"].waitForExistence(timeout: 5))
  }

}
