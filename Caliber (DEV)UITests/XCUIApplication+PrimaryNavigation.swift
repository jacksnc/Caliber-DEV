import XCTest

extension XCUIApplication {
  /// Food Library sits under Fuel, which holds the diary.
  @MainActor
  func openFoodLibrary(file: StaticString = #filePath, line: UInt = #line) {
    let fuel = tab("Fuel")
    XCTAssertTrue(fuel.waitForExistence(timeout: 20), file: file, line: line)
    fuel.tap()
    let library = buttons["openFoodLibrary"]
    XCTAssertTrue(library.waitForExistence(timeout: 10), file: file, line: line)
    library.tap()
    XCTAssertTrue(navigationBars["Food Library"].waitForExistence(timeout: 10), file: file, line: line)
  }

  /// A primary tab in the custom floating bar: "Today", "Train", "Fuel", "Stack" or "Progress".
  func tab(_ title: String) -> XCUIElement { buttons["tab-" + title.lowercased()] }

  /// Profile opens as a sheet from the avatar at the top right of each primary screen.
  @MainActor
  func openProfile(file: StaticString = #filePath, line: UInt = #line) {
    let avatar = buttons["openProfile"].firstMatch
    XCTAssertTrue(avatar.waitForExistence(timeout: 20), file: file, line: line)
    avatar.tap()
    XCTAssertTrue(navigationBars["Profile"].waitForExistence(timeout: 10), file: file, line: line)
  }

  @MainActor
  func closeProfile(file: StaticString = #filePath, line: UInt = #line) {
    buttons["closeProfile"].tap()
    XCTAssertTrue(
      navigationBars["Profile"].waitForNonExistence(timeout: 5), file: file, line: line)
  }

  /// Backs out of anything pushed inside the Profile sheet, then closes it.
  @MainActor
  func leaveProfile(file: StaticString = #filePath, line: UInt = #line) {
    let close = buttons["closeProfile"]
    for _ in 0..<4 where !close.isHittable {
      navigationBars.buttons.element(boundBy: 0).tap()
    }
    closeProfile(file: file, line: line)
  }

  /// Settings is the first row of Profile.
  @MainActor
  func openSettings(file: StaticString = #filePath, line: UInt = #line) {
    openProfile(file: file, line: line)
    let settings = buttons["openSettings"]
    // The list is lazy: a row that is off screen is not created until it scrolls into view.
    for _ in 0..<8 where !settings.waitForExistence(timeout: 2) || !settings.isHittable {
      swipeUp()
    }
    XCTAssertTrue(settings.isHittable, file: file, line: line)
    settings.tap()
    XCTAssertTrue(navigationBars["Settings"].waitForExistence(timeout: 10), file: file, line: line)
  }
}

extension XCUIElement {
  /// Taps near the trailing edge, so the caret lands after any existing text, and retries
  /// until the field has keyboard focus. A field in a sheet exists before the sheet stops
  /// moving, and a tap during that animation leaves nothing focused for `typeText`.
  @MainActor
  func focusAtEnd(file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<5 {
      coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
      if XCUIApplication().keyboards.firstMatch.waitForExistence(timeout: 1) { return }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTFail("The text field never received keyboard focus", file: file, line: line)
  }
}
