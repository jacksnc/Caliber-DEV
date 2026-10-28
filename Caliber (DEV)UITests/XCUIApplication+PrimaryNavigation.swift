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
    XCTAssertTrue(
      navigationBars["Food Library"].waitForExistence(timeout: 10), file: file, line: line)
  }

  /// The compact header a primary screen draws in place of a large navigation title.
  func screenTitle(_ title: String) -> XCUIElement {
    descendants(matching: .any)["screenTitle-" + title]
  }

  /// A primary tab in the custom floating bar: "Today", "Train", "Fuel", "Stack" or "Progress".
  func tab(_ title: String) -> XCUIElement { buttons["tab-" + title.lowercased()] }

  /// Profile opens as a sheet from the avatar at the top right of each primary screen.
  @MainActor
  func openProfile(file: StaticString = #filePath, line: UInt = #line) {
    let avatar = buttons["openProfile"].firstMatch
    // The look-book avatar is beside the content heading, so reveal that heading
    // after reading lower down a scrollable screen.
    for _ in 0..<8 where !avatar.exists || !avatar.isHittable { swipeDown() }
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

  /// Taps `element` until `target` appears. A tap that lands while a list is still
  /// decelerating only stops the scroll.
  @MainActor
  func tap(
    _ element: XCUIElement, until target: XCUIElement, file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for _ in 0..<3 {
      if element.isHittable { element.tap() }
      if target.waitForExistence(timeout: 3) { return }
    }
    XCTFail("\(target) did not appear", file: file, line: line)
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
  /// Replaces a text field's whole value. Placing the caret by coordinate proved unreliable
  /// on CI, so this focuses the field, selects everything from the edit menu and types over it.
  @MainActor
  func replaceText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(waitForExistence(timeout: 5), file: file, line: line)
    // A field in a sheet exists before the sheet stops moving.
    Thread.sleep(forTimeInterval: 1)
    tap()
    press(forDuration: 1.2)
    let selectAll = XCUIApplication().menuItems["Select All"]
    if selectAll.waitForExistence(timeout: 3) {
      selectAll.tap()
    } else {
      // No menu: the caret is in the field, so delete generously before typing.
      let length = (value as? String)?.count ?? 0
      typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: length + 2))
    }
    typeText(text)
  }
}
