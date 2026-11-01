import XCTest

/// Opens the extension's real URL scheme through iOS; never calls an in-app test router.
final class WidgetRoutingUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--showcase-fixture", "--theme-frost"]
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    return app
  }

  @MainActor private func open(_ address: String) {
    XCUIDevice.shared.system.open(URL(string: address)!)
  }

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor private func dismissFoodSearch(in app: XCUIApplication) {
    if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    let bar = app.navigationBars["Search Foods"]
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
      forDuration: 0.05,
      thenDragTo: app.windows.firstMatch.coordinate(
        withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
    XCTAssertTrue(bar.waitForNonExistence(timeout: 5))
  }

  @MainActor func testWidgetFuelURLReturnsToDiaryFromFoodLibrary() {
    let app = launch()
    app.openFoodLibrary()
    open("caliber://fuel")
    XCTAssertTrue(app.buttons["openFoodLibrary"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["openFoodLibrary"].isHittable)
    capture("Widget Fuel route returns to Frost Diary", app: app)
  }

  @MainActor func testWidgetAddURLShowsEditableFoodSearchWithoutLogging() {
    let app = launch()
    open("caliber://food/add")
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(app.navigationBars["Search Foods"].exists)
    dismissFoodSearch(in: app)
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "1462 calories")
  }

  @MainActor func testWidgetFuelURLRestoresTodayRatherThanThePreviouslySelectedDay() {
    let app = launch()
    app.tab("Fuel").tap()
    app.buttons["diaryNextDay"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "0 calories")
    app.tab("Train").tap()
    open("caliber://fuel")
    XCTAssertTrue(app.buttons["openFoodLibrary"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "1462 calories")
  }

  @MainActor func testWidgetRouteWaitsUntilProfileIsClosed() {
    let app = launch()
    app.openProfile()
    open("caliber://fuel")
    XCTAssertTrue(app.navigationBars["Profile"].exists)
    app.closeProfile()
    XCTAssertTrue(app.buttons["openFoodLibrary"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["openFoodLibrary"].isHittable)
  }

  @MainActor func testRepeatedAddURLPreservesSearchAndFuelURLWaitsForDismissal() {
    let app = launch()
    open("caliber://food/add")
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.tap()
    search.typeText("oikos")
    open("caliber://food/add")
    XCTAssertEqual(search.value as? String, "oikos")
    open("caliber://fuel")
    XCTAssertEqual(search.value as? String, "oikos")
    dismissFoodSearch(in: app)
    XCTAssertTrue(app.buttons["openFoodLibrary"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "1462 calories")
  }

  @MainActor func testWidgetFuelURLDoesNotDiscardAPushedLibrarySearch() {
    let app = launch()
    app.openFoodLibrary()
    app.buttons["openFoodSearch"].tap()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.tap()
    search.typeText("oikos")
    open("caliber://fuel")
    XCTAssertEqual(search.value as? String, "oikos")
    if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    // iOS can expose Close for the active search before the normal Back button.
    // Finish that presentation, then back out of the preserved search branch.
    for _ in 0..<3 where !app.buttons["openFoodLibrary"].exists {
      app.navigationBars.firstMatch.buttons.element(boundBy: 0).tap()
    }
    XCTAssertTrue(app.buttons["openFoodLibrary"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["openFoodLibrary"].isHittable)
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "1462 calories")
  }

  @MainActor func testWidgetURLsCannotLeaveNumberFreeMode() {
    let app = launch()
    app.openSettings()
    let privacy = app.switches["hideNumbers"]
    for _ in 0..<8 where !privacy.isHittable { app.swipeUp() }
    XCTAssertTrue(privacy.isHittable)
    privacy.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    if app.buttons["closeProfile"].exists { app.leaveProfile() }
    for address in ["caliber://fuel", "caliber://food/add"] {
      open(address)
      XCTAssertTrue(app.staticTexts["Numbers are hidden"].waitForExistence(timeout: 10))
      XCTAssertFalse(app.tab("Fuel").exists)
      XCTAssertFalse(app.searchFields.firstMatch.exists)
    }
  }

  @MainActor func testWidgetAddURLPreservesAnUnsavedProgressNoteUntilCancel() {
    let app = launch()
    app.tab("Progress").tap()
    let add = app.buttons["addProgressEntry"]
    XCTAssertTrue(add.waitForExistence(timeout: 10))
    add.tap()
    let notes = app.textViews["progressNotes"]
    for _ in 0..<8 where !notes.isHittable { app.swipeUp() }
    XCTAssertTrue(notes.isHittable)
    notes.tap()
    notes.typeText("Unsaved widget navigation draft")
    let before = notes.value as? String
    open("caliber://food/add")
    XCTAssertTrue(notes.exists)
    XCTAssertEqual(notes.value as? String, before)
    XCTAssertFalse(app.searchFields.firstMatch.exists)
    capture("Widget route preserves a fictional unsaved check-in note", app: app)
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
    dismissFoodSearch(in: app)
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "1462 calories")
  }
}
