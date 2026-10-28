import XCTest

final class TrainProfileUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor
  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"]
    app.launch()
    XCTAssertTrue(app.tab("Train").waitForExistence(timeout: 20))
    return app
  }

  @MainActor
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    // A full-screen swipe can move a form field past the top while its numeric
    // keyboard is open. Short drags follow the field in either direction.
    for _ in 0..<16 {
      let top = app.navigationBars.firstMatch.frame.maxY
      let bottom =
        app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.maxY
      if element.exists && element.isHittable && element.frame.minY > top
        && element.frame.maxY < bottom - 8
      {
        break
      }
      let delta: CGFloat = element.exists && element.frame.minY < top ? 140 : -140
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
      start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
    }
    XCTAssertTrue(element.isHittable)
  }

  @MainActor
  private func type(_ value: String, into field: XCUIElement, in app: XCUIApplication) {
    reveal(field, in: app)
    field.tap()
    field.typeText(value)
  }

  @MainActor func testProfileCalculatesAndSavesLocalGoals() {
    let app = launch()
    app.openProfile()
    type("30", into: app.textFields["profileAge"], in: app)
    type("70", into: app.textFields["profileHeight"], in: app)
    type("180", into: app.textFields["profileWeight"], in: app)
    let calculate = app.buttons["profileCalculate"]
    reveal(calculate, in: app)
    calculate.tap()
    XCTAssertTrue(app.alerts["Profile"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.alerts["Profile"].staticTexts["Your estimated daily goals were saved on this device."]
        .exists)
    app.alerts["Profile"].buttons["OK"].tap()
    let savedGoal = app.descendants(matching: .any)["profileSavedCalorieGoal"]
    reveal(savedGoal, in: app)
    XCTAssertTrue(savedGoal.waitForExistence(timeout: 5))
  }

  @MainActor func testWorkoutSetSavesAndFinishedWorkoutAppearsInHistory() {
    let app = launch()
    app.tab("Train").tap()
    app.buttons["startWorkout"].tap()
    XCTAssertTrue(app.screenTitle("ActiveWorkout").waitForExistence(timeout: 5))
    app.buttons["Add Exercise"].firstMatch.tap()
    let bench = app.buttons["Bench Press"]
    XCTAssertTrue(bench.waitForExistence(timeout: 5))
    bench.tap()
    type("135", into: app.textFields["Weight"], in: app)
    type("8", into: app.textFields["Reps"], in: app)
    app.buttons["Complete set 1"].tap()
    // The look-book grid exposes saved weight and reps as separate cells.
    XCTAssertTrue(app.buttons["Set 1 completed"].waitForExistence(timeout: 5))
    app.buttons["finishWorkout"].tap()
    app.buttons["Finish Workout"].tap()
    XCTAssertTrue(app.screenTitle("Train").waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1 sets")).firstMatch
        .waitForExistence(timeout: 5))
  }
}
