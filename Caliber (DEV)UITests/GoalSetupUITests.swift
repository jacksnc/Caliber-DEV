import XCTest

final class GoalSetupUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch(
    firstRun: Bool = false, theme: String = "graphite", large: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--theme-\(theme)"]
    if firstRun { app.launchArguments.append("--goal-setup-first-run") }
    if large {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    return app
  }

  @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
    for _ in 0..<14 {
      let top = app.navigationBars.firstMatch.frame.maxY
      let footer =
        ["goalSetupNext", "goalSetupSave", "goalSetupCancel"].map { app.buttons[$0] }
        .filter { $0.exists }.map { $0.frame.minY }.min() ?? app.frame.maxY
      if element.exists && element.isHittable && element.frame.minY > top
        && element.frame.maxY < footer - 8
      {
        return
      }
      let delta: CGFloat = element.exists && element.frame.minY < top ? 150 : -150
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
      start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
    }
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    XCTAssertTrue(element.isHittable)
  }

  @MainActor private func type(
    _ value: String, id: String, app: XCUIApplication, replace: Bool = false
  ) {
    let field = app.textFields[id]
    reveal(field, app: app)
    if replace {
      field.replaceText(value)
    } else {
      field.tap()
      field.typeText(value)
    }
    let done = app.buttons["goalSetupKeyboardDone"]
    if done.waitForExistence(timeout: 3) { done.tap() }
  }

  @MainActor private func open(_ app: XCUIApplication) {
    app.openProfile()
    let setup = app.buttons["openGoalSetup"]
    reveal(setup, app: app)
    setup.tap()
    XCTAssertTrue(app.textFields["goalSetupAge"].waitForExistence(timeout: 5))
  }

  @MainActor private func enterBody(_ app: XCUIApplication) {
    type("30", id: "goalSetupAge", app: app)
    type("70", id: "goalSetupHeight", app: app)
    type("180", id: "goalSetupWeight", app: app)
    app.buttons["goalSetupNext"].tap()
    let equation = app.buttons["goalSetupEquation-plusFive"]
    reveal(equation, app: app)
    equation.tap()
    app.buttons["goalSetupNext"].tap()
  }

  @MainActor func testNewWelcomeOffersOptionalSetupAfterBothConfirmations() {
    let app = XCUIApplication()
    app.launchArguments = [
      "--foundation-ui-testing", "--reset-foundation", "--goal-setup-first-run",
    ]
    app.launch()
    let proceed = app.buttons["welcomeContinue"]
    XCTAssertTrue(proceed.waitForExistence(timeout: 20))
    XCTAssertFalse(proceed.isEnabled)
    // Tap the switch itself after the welcome layout settles, as in the gate tests.
    for name in ["adultConfirmation", "scopeConfirmation"] {
      let toggle = app.switches[name]
      for _ in 0..<3 where toggle.value as? String != "1" {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
      }
      XCTAssertEqual(toggle.value as? String, "1")
    }
    XCTAssertTrue(proceed.isEnabled)
    proceed.tap()
    XCTAssertTrue(app.textFields["goalSetupAge"].waitForExistence(timeout: 10))
    app.buttons["goalSetupCancel"].tap()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 5))
    XCTAssertTrue(app.tab("Today").isHittable)
  }

  @MainActor func testFirstRunCanSkipAndReturnToEmptySetup() {
    let app = launch(firstRun: true)
    let skip = app.buttons["goalSetupCancel"]
    XCTAssertTrue(skip.waitForExistence(timeout: 20))
    skip.tap()
    open(app)
    XCTAssertTrue((app.textFields["goalSetupAge"].value as? String ?? "").isEmpty)
    XCTAssertFalse(app.staticTexts["goalSetupSavedCalories"].exists)
    app.buttons["goalSetupCancel"].tap()
    XCTAssertFalse(app.staticTexts["goalSetupSavedCalories"].exists)
  }

  @MainActor func testSaveReopenAndCancelPreserveExplicitGoals() {
    let app = launch()
    open(app)
    enterBody(app)
    let loss = app.buttons["goalSetupGoal-cut"]
    reveal(loss, app: app)
    loss.tap()
    type("170", id: "goalSetupTargetWeight", app: app)
    app.buttons["goalSetupNext"].tap()
    let edit = app.switches["goalSetupEditTargets"]
    reveal(edit, app: app)
    edit.tap()
    type("2000", id: "goalSetupCalories", app: app, replace: true)
    app.buttons["goalSetupSave"].tap()
    let calories = app.staticTexts["goalSetupSavedCalories"]
    XCTAssertTrue(calories.waitForExistence(timeout: 10))
    XCTAssertTrue(calories.label.replacingOccurrences(of: ",", with: "").contains("2000"))
    XCTAssertTrue(app.staticTexts["goalSetupSavedTargetWeight"].label.contains("170"))

    reveal(app.buttons["openGoalSetup"], app: app)
    app.buttons["openGoalSetup"].tap()
    XCTAssertTrue(app.textFields["goalSetupAge"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["goalSetupAge"].value as? String, "30")
    app.buttons["goalSetupNext"].tap()
    app.buttons["goalSetupNext"].tap()
    app.buttons["goalSetupNext"].tap()
    let review = app.staticTexts["goalSetupReviewCalories"]
    XCTAssertTrue(review.waitForExistence(timeout: 5))
    XCTAssertTrue(review.label.replacingOccurrences(of: ",", with: "").contains("2000"))
    app.buttons["goalSetupSave"].tap()
    XCTAssertTrue(calories.waitForExistence(timeout: 5))
    reveal(app.buttons["openGoalSetup"], app: app)
    app.buttons["openGoalSetup"].tap()
    type("40", id: "goalSetupAge", app: app, replace: true)
    app.buttons["goalSetupCancel"].tap()
    let age = app.textFields["profileAge"]
    reveal(age, app: app)
    XCTAssertEqual(age.value as? String, "30")
  }

  @MainActor func testInvalidAgeAndMissingEquationCannotAdvance() {
    let app = launch()
    open(app)
    type("17", id: "goalSetupAge", app: app)
    type("70", id: "goalSetupHeight", app: app)
    type("180", id: "goalSetupWeight", app: app)
    app.buttons["goalSetupNext"].tap()
    XCTAssertTrue(app.staticTexts["goalSetupError"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["goalSetupStep"].label.contains("1 of 4"))
    type("30", id: "goalSetupAge", app: app, replace: true)
    app.buttons["goalSetupNext"].tap()
    app.buttons["goalSetupNext"].tap()
    let error = app.staticTexts["goalSetupError"]
    XCTAssertTrue(error.waitForExistence(timeout: 5))
    XCTAssertTrue(error.label.contains("Choose an equation"))
    app.buttons["goalSetupCancel"].tap()
    XCTAssertFalse(app.staticTexts["goalSetupSavedCalories"].exists)
  }

  @MainActor func testThemesAndLargestTextSetupScreen() throws {
    for (theme, large) in [("graphite", false), ("frost", false), ("graphite", true)] {
      let app = launch(theme: theme, large: large)
      open(app)
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "goal-setup-\(theme)-\(large ? "AX5" : "default")"
      capture.lifetime = .keepAlways
      add(capture)
      try app.auditRepeatedIssues(for: large ? [.dynamicType, .textClipped] : [.textClipped])
      app.buttons["goalSetupCancel"].tap()
      app.terminate()
    }
  }
}
