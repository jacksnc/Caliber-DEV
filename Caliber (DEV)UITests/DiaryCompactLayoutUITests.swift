import XCTest

/// Compact-height Diary on a real rotation, with the fictional in-memory showcase store
/// (which has a saved calorie goal, so the ringed figure is the case under test).
final class DiaryCompactLayoutUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch() -> XCUIApplication {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--showcase-fixture", "--theme-frost"]
    app.launch()
    XCTAssertTrue(app.tab("Fuel").waitForExistence(timeout: 20))
    app.tab("Fuel").tap()
    XCTAssertTrue(app.staticTexts["diaryCalories"].waitForExistence(timeout: 10))
    return app
  }

  @MainActor private func rotate(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
    XCUIDevice.shared.orientation = orientation
    let landscape = orientation.isLandscape
    let settled = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let frame = app.windows.firstMatch.frame
        return landscape ? frame.width > frame.height : frame.height > frame.width
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed)
  }

  @MainActor private func capture(_ name: String) {
    // Full screen: an app-only crop can keep a portrait transform after rotation.
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// On screen at the current scroll position, above the floating bar, with a 48pt target.
  @MainActor private func assertReachable(
    _ element: XCUIElement, app: XCUIApplication, minimumTarget: Bool = true,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
    XCTAssertTrue(element.isHittable, file: file, line: line)
    let window = app.windows.firstMatch.frame
    let bar = app.otherElements["caliberTabBar"]
    let bottom = bar.exists ? bar.frame.minY : window.maxY
    XCTAssertGreaterThanOrEqual(element.frame.minX, window.minX - 1, file: file, line: line)
    XCTAssertLessThanOrEqual(element.frame.maxX, window.maxX + 1, file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.minY, window.minY, file: file, line: line)
    XCTAssertLessThanOrEqual(element.frame.maxY, bottom, file: file, line: line)
    guard minimumTarget else { return }
    XCTAssertGreaterThanOrEqual(element.frame.width, 47.5, file: file, line: line)
    XCTAssertGreaterThanOrEqual(element.frame.height, 47.5, file: file, line: line)
  }

  @MainActor func testLandscapeShowsCaloriesWithEveryHeaderAction() throws {
    let app = launch()
    defer { XCUIDevice.shared.orientation = .portrait }
    rotate(.landscapeLeft, app: app)
    guard app.windows.firstMatch.frame.height < 500 else {
      throw XCTSkip("Compact height only: this destination is not a short landscape phone.")
    }

    // Initial scroll position: no drag before these checks.
    let calories = app.staticTexts["diaryCalories"]
    XCTAssertTrue(calories.waitForExistence(timeout: 5))
    XCTAssertTrue(calories.isHittable)
    XCTAssertEqual(calories.label, "1462 calories")
    let bar = app.otherElements["caliberTabBar"]
    XCTAssertTrue(bar.exists)
    XCTAssertLessThanOrEqual(calories.frame.maxY, bar.frame.minY)
    XCTAssertGreaterThanOrEqual(calories.frame.minY, app.windows.firstMatch.frame.minY)

    let previous = app.buttons["diaryPreviousDay"]
    let next = app.buttons["diaryNextDay"]
    let library = app.buttons["openFoodLibrary"]
    let copy = app.buttons["diaryCopyDay"]
    let date = app.descendants(matching: .any)["diaryDate"].firstMatch
    for control in [previous, next, library, copy, date] { assertReachable(control, app: app) }
    XCTAssertEqual(previous.label, "Previous diary day")
    XCTAssertEqual(next.label, "Next diary day")
    XCTAssertEqual(library.label, "Food Library")
    XCTAssertEqual(copy.label, "Copy a Day")
    capture("diary-compact-landscape-initial")

    // Day movement still drives the same totals.
    next.tap()
    let moved = NSPredicate(format: "label != %@", "1462 calories")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: moved, object: calories)], timeout: 5),
      .completed)
    previous.tap()
    let back = NSPredicate(format: "label == %@", "1462 calories")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: back, object: calories)], timeout: 5),
      .completed)

    // Food Library pushes and returns; Copy a Day opens its sheet and cancels.
    library.tap()
    XCTAssertTrue(app.navigationBars["Food Library"].waitForExistence(timeout: 10))
    // The pushed library survives the layout switch in both directions.
    rotate(.portrait, app: app)
    XCTAssertTrue(app.navigationBars["Food Library"].waitForExistence(timeout: 5))
    rotate(.landscapeLeft, app: app)
    XCTAssertTrue(app.navigationBars["Food Library"].waitForExistence(timeout: 5))
    app.navigationBars["Food Library"].buttons.element(boundBy: 0).tap()
    XCTAssertTrue(library.waitForExistence(timeout: 10))
    assertReachable(calories, app: app, minimumTarget: false)
    copy.tap()
    XCTAssertTrue(app.buttons["copyConfirm"].waitForExistence(timeout: 10))
    app.navigationBars["Copy Foods"].buttons["Cancel"].tap()
    XCTAssertTrue(copy.waitForExistence(timeout: 10))
    assertReachable(copy, app: app)
    XCTAssertEqual(calories.label, "1462 calories")
    XCTAssertTrue(calories.isHittable)

    // Portrait keeps the same controls and day.
    rotate(.portrait, app: app)
    for control in [previous, next, library, copy, date] { assertReachable(control, app: app) }
    XCTAssertEqual(calories.label, "1462 calories")
    capture("diary-compact-portrait-after-rotation")
  }
}
