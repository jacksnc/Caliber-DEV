import XCTest

/// Functional checks for the reference layout, using fictional data in memory.
final class LookbookPolishUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch(workout: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--progress-ui-testing", "--theme-graphite", "--showcase-fixture", "--stack-fixture",
    ]
    if workout { app.launchArguments.append("--showcase-workout") }
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    return app
  }

  @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication, down: Bool = false) {
    for _ in 0..<7 where !element.exists || !element.isHittable {
      if down { app.swipeDown() } else { app.swipeUp() }
    }
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    XCTAssertTrue(element.isHittable)
  }

  @MainActor func testAvatarSharesTheHeadingAndProfileStillOpens() {
    let app = launch()
    let title = app.screenTitle("Today")
    let avatar = app.buttons["openProfile"]
    XCTAssertTrue(avatar.waitForExistence(timeout: 5))
    // The old toolbar put the avatar a whole navigation row above the title.
    XCTAssertLessThan(abs(avatar.frame.midY - title.frame.midY), 28)
    app.openProfile()
    XCTAssertTrue(app.buttons["closeProfile"].waitForExistence(timeout: 5))
    app.closeProfile()
    XCTAssertTrue(app.screenTitle("Today").exists)
  }

  @MainActor func testProgressOverviewKeepsItsChartsAndMethodAccessible() {
    let app = launch()
    app.tab("Progress").tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["latestProgressWeight"].waitForExistence(timeout: 5))
    let calories = app.descendants(matching: .any)["progressCalories"]
    let split = app.descendants(matching: .any)["progressMacroSplit"]
    XCTAssertTrue(calories.waitForExistence(timeout: 5))
    for _ in 0..<5 where !split.exists { app.swipeUp() }
    XCTAssertTrue(split.waitForExistence(timeout: 5))
    let method = app.buttons["weightTrendMethod"]
    reveal(method, app: app, down: true)
    method.tap()
    XCTAssertTrue(app.navigationBars["Weight trend"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts[
        "Each dot is a recorded weigh-in; the line is the smoothed trend. Dates run from oldest to newest."
      ].exists)
    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["addProgressEntry"].waitForExistence(timeout: 5))
  }

  @MainActor func testCollapsingWorkoutCardsRetainsUncompletedInputAndOptions() {
    let app = launch(workout: true)
    app.tab("Train").tap()
    app.buttons["resumeWorkout"].tap()
    let weight = app.textFields["Weight"].firstMatch
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    weight.tap()
    weight.typeText(".5")
    let edited = weight.value as? String
    app.buttons["workoutKeyboardDone"].tap()
    let incline = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
        "workoutExercise-", "Incline Dumbbell Press")
    ).firstMatch
    reveal(incline, app: app)
    incline.tap()
    let bench = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
        "workoutExercise-", "Bench Press")
    ).firstMatch
    reveal(bench, app: app, down: true)
    bench.tap()
    let restored = app.textFields["Weight"].firstMatch
    reveal(restored, app: app)
    XCTAssertEqual(restored.value as? String, edited)
    let options = app.buttons["Set options"].firstMatch
    reveal(options, app: app)
    options.tap()
    XCTAssertTrue(app.textFields["RPE"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.switches["Warm-up set"].exists)
  }
}
