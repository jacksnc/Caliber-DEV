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
    XCTAssertTrue(settings.waitForExistence(timeout: 10), file: file, line: line)
    settings.tap()
    XCTAssertTrue(navigationBars["Settings"].waitForExistence(timeout: 10), file: file, line: line)
  }
}
