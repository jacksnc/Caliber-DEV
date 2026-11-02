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
    // A tap that lands while the welcome screen is still settling can be lost; retry it.
    for name in ["adultConfirmation", "scopeConfirmation"] {
      let toggle = app.switches[name]
      for _ in 0..<3 where toggle.value as? String != "1" {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
      }
      XCTAssertEqual(toggle.value as? String, "1")
    }
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
    let tableButton = app.buttons["chartTable-Body weight"]
    reveal(tableButton, in: app)
    tableButton.tap()
    XCTAssertTrue(app.navigationBars["Body weight"].waitForExistence(timeout: 5))
    let notLogged = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Not logged")
    ).firstMatch
    reveal(notLogged, in: app)
    XCTAssertTrue(notLogged.waitForExistence(timeout: 5))
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
    // Navigation pushes and sheets keep their presenters in the accessibility tree.
    // The active form/table is the last scroll container, not the background tab.
    let collectionViews = app.collectionViews.allElementsBoundByIndex
    let collection = collectionViews.last ?? app.collectionViews.firstMatch
    let scrollViews = app.scrollViews.allElementsBoundByIndex
    let scroll = scrollViews.last ?? app.scrollViews.firstMatch
    let navigationBar = app.navigationBars.firstMatch
    let tabBar = app.otherElements["caliberTabBar"]
    let demoExit = app.buttons["exitDemo"]
    for _ in 0..<40 {
      let top = navigationBar.exists ? navigationBar.frame.maxY + 8 : 64
      let isRecoverySheet = app.navigationBars["Password Recovery"].exists
      let bottom: CGFloat
      if tabBar.exists && !isRecoverySheet {
        bottom = tabBar.frame.minY - 8
      } else if demoExit.exists {
        bottom = demoExit.frame.minY - 8
      } else {
        bottom = app.windows.firstMatch.frame.maxY - 16
      }
      if element.exists {
        let frame = element.frame
        let visibleHeight = min(frame.maxY, bottom) - max(frame.minY, top)
        if element.isHittable && visibleHeight >= min(48, frame.height) { return }
        let target: XCUIElement
        if collection.exists {
          target = collection
        } else if scroll.exists {
          target = scroll
        } else {
          target = app
        }
        // Small drags near an edge avoid jumping past tall Dynamic Type controls.
        let needsDownwardContent = frame.minY < top
        let gap = needsDownwardContent ? top - frame.minY : frame.maxY - bottom
        if gap > 400 {
          if needsDownwardContent { target.swipeDown() } else { target.swipeUp() }
        } else {
          let distance = min(max(gap + 56, 100), 180)
          // The charts handle vertical drags for data inspection. Drag at the
          // trailing gutter so the parent dashboard scroll view receives them.
          let start = target.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.55))
          let verticalDelta = needsDownwardContent ? distance : -distance
          start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: verticalDelta)))
        }
      } else if collection.exists {
        collection.swipeUp()
      } else if scroll.exists {
        scroll.swipeUp()
      } else {
        app.swipeUp()
      }
    }
    let top = navigationBar.exists ? navigationBar.frame.maxY + 8 : 64
    let isRecoverySheet = app.navigationBars["Password Recovery"].exists
    let bottom: CGFloat
    if tabBar.exists && !isRecoverySheet {
      bottom = tabBar.frame.minY - 8
    } else if demoExit.exists {
      bottom = demoExit.frame.minY - 8
    } else {
      bottom = app.windows.firstMatch.frame.maxY - 16
    }
    XCTAssertTrue(
      element.exists && element.isHittable
        && min(element.frame.maxY, bottom) - max(element.frame.minY, top)
          >= min(48, element.frame.height),
      "Could not reveal \(element.identifier) above the tab bar.\n\(app.debugDescription)")
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
    weight.replaceText("175,25")
    app.buttons["Cancel"].tap()
    app.buttons["addProgressEntry"].tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "180,5")
  }

  @MainActor func testAccountSignInAndDeviceSignOutUseOnlyFixture() {
    let app = launch(additionalArguments: ["--account-ui-testing"])
    // Account opens from Profile's own row, near the top, so no scrolling is needed.
    app.openProfile()
    app.tap(app.buttons["profileAccount"], until: app.switches["accountConsent"])
    let consent = app.switches["accountConsent"]
    reveal(consent, in: app)
    XCTAssertFalse(app.buttons["accountConsentContinue"].isEnabled)
    turnOn(consent)
    let continueToAccount = app.buttons["accountConsentContinue"]
    reveal(continueToAccount, in: app)
    XCTAssertTrue(continueToAccount.isEnabled, app.debugDescription)
    continueToAccount.tap()
    let email = revealAccountEmail(in: app)
    email.tap()
    email.typeText("fixture@example.invalid")
    app.secureTextFields["accountPassword"].tap()
    app.secureTextFields["accountPassword"].typeText("fixture-password")
    app.buttons["accountSignIn"].tap()
    // Each step on the shared CI simulator can take several seconds to settle.
    XCTAssertTrue(app.staticTexts["accountSignedIn"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.staticTexts["accountMessage"].label.contains("cloud backup is not active"))
    app.buttons["accountSignOut"].tap()
    XCTAssertTrue(email.waitForExistence(timeout: 5))
    XCTAssertEqual(app.secureTextFields["accountPassword"].value as? String, "Password")
    XCTAssertEqual(app.staticTexts["accountMessage"].label, "Signed out on this device.")
  }

  /// Every issue is printed with its element, so CI logs say what failed; issues that
  /// repeat on a second pass fail the test (D113).
  @MainActor private func audit(_ app: XCUIApplication) throws {
    try app.auditRepeatedIssues(for: [.dynamicType, .textClipped, .hitRegion])
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
    XCTAssertTrue(app.navigationBars["Demo"].waitForExistence(timeout: 5))

    let info = app.buttons["chartInfo-Body weight"]
    reveal(info, in: app)
    XCTAssertTrue(info.isHittable)
    XCTAssertGreaterThanOrEqual(info.frame.width, 48)
    XCTAssertGreaterThanOrEqual(info.frame.height, 48)
    info.tap()
    let methodCopy = app.staticTexts["How we calculate"]
    XCTAssertTrue(methodCopy.waitForExistence(timeout: 8), app.debugDescription)
    try audit(app)
    let methodPicture = XCTAttachment(screenshot: app.screenshot())
    methodPicture.name = "Foundation calculation method AX5"
    methodPicture.lifetime = .keepAlways
    add(methodPicture)
    // Exit Demo belongs to the dashboard; the chart pages go back to it first.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["exitDemo"].waitForExistence(timeout: 5))
    app.buttons["exitDemo"].tap()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 5))
  }

  /// A tap that lands while a screen is still settling can be lost; retry until it is on.
  @MainActor private func turnOn(_ toggle: XCUIElement) {
    for _ in 0..<3 where toggle.value as? String != "1" {
      toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }
    XCTAssertEqual(toggle.value as? String, "1")
  }

  @MainActor private func openFixtureAccount(in app: XCUIApplication) {
    app.openProfile()
    let consent = app.switches["accountConsent"]
    app.tap(app.buttons["profileAccount"], until: consent)
    reveal(consent, in: app)
    turnOn(consent)
    let continueToAccount = app.buttons["accountConsentContinue"]
    reveal(continueToAccount, in: app)
    XCTAssertTrue(continueToAccount.isEnabled, app.debugDescription)
    continueToAccount.tap()
    _ = revealAccountEmail(in: app)
  }

  /// Consent content is taller than the phone viewport. Returning to the account fields
  /// also ensures SwiftUI's Form has materialized their accessibility elements.
  @MainActor private func revealAccountEmail(in app: XCUIApplication) -> XCUIElement {
    let email = app.textFields["accountEmail"]
    for _ in 0..<8 where !email.exists || !email.isHittable {
      app.swipeDown()
    }
    XCTAssertTrue(email.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(email.isHittable, app.debugDescription)
    return email
  }
  @MainActor func testRecoveryUsesCodeWithoutSigningIn() {
    let app = launch(additionalArguments: ["--account-ui-testing"])
    openFixtureAccount(in: app)
    app.buttons["accountRecover"].tap()
    let email = app.textFields["recoveryEmail"]
    XCTAssertTrue(email.waitForExistence(timeout: 5))
    email.tap()
    email.typeText("fixture@example.invalid")
    let request = app.buttons["recoverySend"]
    XCTAssertTrue(request.isEnabled)
    request.tap()
    let requestMessage = app.staticTexts["recoveryMessage"]
    reveal(requestMessage, in: app)
    XCTAssertTrue(requestMessage.waitForExistence(timeout: 5), app.debugDescription)
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
    let resetMessage = app.staticTexts["recoveryMessage"]
    // Success is inserted at the top of the form, while the submitted button was at its end.
    for _ in 0..<8 where !resetMessage.exists || !resetMessage.isHittable { app.swipeDown() }
    XCTAssertTrue(resetMessage.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertEqual(
      resetMessage.label, "Password changed. Sign in with your new password.")
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
    // Each step on the shared CI simulator can take several seconds to settle.
    XCTAssertTrue(app.staticTexts["accountSignedIn"].waitForExistence(timeout: 20))
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
    let consent = app.switches["accountConsent"]
    // The consent switch sits below its disclosure copy, so scroll the form to its end.
    for _ in 0..<8 where !consent.exists || !consent.isHittable { app.swipeUp() }
    XCTAssertTrue(consent.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertEqual(consent.value as? String, "0")
    XCTAssertFalse(app.buttons["accountConsentContinue"].isEnabled)
    let deletionMessage = app.staticTexts["accountMessage"]
    for _ in 0..<8 where !deletionMessage.exists || !deletionMessage.isHittable { app.swipeDown() }
    XCTAssertTrue(deletionMessage.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(deletionMessage.label.contains("Your local logs and photos are still here"))
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "Hosted deletion fixture"
    picture.lifetime = .keepAlways
    add(picture)
    app.leaveProfile()
    app.tab("Progress").tap()
    let localNote = app.staticTexts["Kept after hosted deletion"]
    reveal(localNote, in: app)
    XCTAssertTrue(localNote.waitForExistence(timeout: 5), app.debugDescription)
  }

}
