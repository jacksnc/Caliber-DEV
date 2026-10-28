import XCTest

final class CustomExerciseUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"]
    app.launch()
    XCTAssertTrue(app.tab("Train").waitForExistence(timeout: 20))
    app.tab("Train").tap()
    return app
  }

  @MainActor private func type(_ value: String, into field: XCUIElement) {
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText(value)
  }

  @MainActor func testMissingExerciseCanBeCreatedInWorkoutAndReusedFromLibrary() {
    let app = launch()
    app.buttons["startWorkout"].tap()
    app.buttons["Add Exercise"].firstMatch.tap()
    let name = "QA Cable Press Variation"
    type(name, into: app.searchFields.firstMatch)
    app.buttons["pickerCreateMissingExercise"].tap()
    let nameField = app.textFields["customExerciseName"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    XCTAssertEqual(nameField.value as? String, name)
    app.buttons["customExerciseSave"].tap()
    let added = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "workoutExercise-", name)
    ).firstMatch
    XCTAssertTrue(added.waitForExistence(timeout: 5))
    type("40", into: app.textFields["Weight"])
    type("8", into: app.textFields["Reps"])
    app.buttons["Complete set 1"].tap()
    XCTAssertTrue(app.buttons["Set 1 completed"].waitForExistence(timeout: 5))
    app.buttons["finishWorkout"].tap()
    app.buttons["Finish Workout"].tap()
    XCTAssertTrue(app.screenTitle("Train").waitForExistence(timeout: 5))
    app.buttons["Exercises"].tap()
    type(name, into: app.searchFields.firstMatch)
    XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
  }

  @MainActor func testCancelDoesNotAddExerciseAndLibraryCreationStillWorks() {
    let app = launch()
    app.buttons["Exercises"].tap()
    app.buttons["libraryCreateExercise"].tap()
    let save = app.buttons["customExerciseSave"]
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    XCTAssertFalse(save.isEnabled)
    type("QA Cancelled Exercise", into: app.textFields["customExerciseName"])
    app.buttons["customExerciseCancel"].tap()
    XCTAssertFalse(app.staticTexts["QA Cancelled Exercise"].exists)
    app.buttons["libraryCreateExercise"].tap()
    type("QA Library Exercise", into: app.textFields["customExerciseName"])
    app.buttons["customExerciseSave"].tap()
    // The sorted library is lazy; reveal the new row through the search users have.
    type("QA Library Exercise", into: app.searchFields.firstMatch)
    XCTAssertTrue(app.staticTexts["QA Library Exercise"].waitForExistence(timeout: 5))
  }
}
