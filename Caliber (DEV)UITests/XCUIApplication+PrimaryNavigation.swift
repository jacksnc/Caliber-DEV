import XCTest

extension XCUIApplication {
  /// Food Library moved under Diary when Train became a primary tab.
  @MainActor
  func openFoodLibrary(file: StaticString = #filePath, line: UInt = #line) {
    let diary = tabBars.buttons["Diary"]
    XCTAssertTrue(diary.waitForExistence(timeout: 20), file: file, line: line)
    diary.tap()
    let library = buttons["openFoodLibrary"]
    XCTAssertTrue(library.waitForExistence(timeout: 10), file: file, line: line)
    library.tap()
    XCTAssertTrue(navigationBars["Food Library"].waitForExistence(timeout: 10), file: file, line: line)
  }

  /// Settings now lives inside the Profile tab.
  @MainActor
  func openSettings(file: StaticString = #filePath, line: UInt = #line) {
    let profile = tabBars.buttons["Profile"]
    XCTAssertTrue(profile.waitForExistence(timeout: 20), file: file, line: line)
    profile.tap()
    let settings = buttons["openSettings"]
    // Settings is the last row of a lazy list. On shorter screens it is not created
    // until it scrolls into view, so waiting alone never finds it.
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
      if (value(forKey: "hasKeyboardFocus") as? Bool) == true { return }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTFail("The text field never received keyboard focus", file: file, line: line)
  }
}
