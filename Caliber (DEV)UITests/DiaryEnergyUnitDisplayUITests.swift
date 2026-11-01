import XCTest

/// Diary, food search and copy previews follow the saved energy unit. Uses only the
/// fictional in-memory showcase store (1,462 kcal logged today against a 2,350 kcal goal)
/// and the isolated UI-test preferences, which reset on each launch.
final class DiaryEnergyUnitDisplayUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    // Settings is a lazy Form, so an off-screen row may not exist in the AX tree yet.
    for _ in 0..<8 where !element.isHittable { app.swipeUp() }
    XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) did not appear")
    XCTAssertTrue(element.isHittable, "\(element) not reachable")
  }

  @MainActor private func choose(energy unit: String, in app: XCUIApplication) {
    app.openSettings()
    let picker = app.descendants(matching: .any)["settingsEnergyUnit"].firstMatch
    reveal(picker, in: app)
    picker.tap()
    let option = app.buttons[unit].firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 5))
    option.tap()
    app.leaveProfile()
    app.tab("Fuel").tap()
  }

  /// The former short label: "420 cal" at the end of a label or before a comma.
  private let oldCalorieLabel = NSPredicate(
    format: "label ENDSWITH %@ OR label CONTAINS %@", " cal", " cal,")

  @MainActor private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor private func dismissSheet(in app: XCUIApplication) {
    let bar = app.navigationBars.firstMatch
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
      forDuration: 0.05, thenDragTo: end)
  }

  @MainActor func testKilojoulesShowAcrossDiarySearchAndCopyThenKilocaloriesReturn() {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--showcase-fixture", "--theme-frost"]
    app.launch()
    XCTAssertTrue(app.tab("Fuel").waitForExistence(timeout: 20))

    // Default kcal: the wording existing tests rely on is unchanged.
    app.tab("Fuel").tap()
    let calories = app.staticTexts["diaryCalories"]
    XCTAssertTrue(calories.waitForExistence(timeout: 10))
    XCTAssertEqual(calories.label, "1462 calories")
    XCTAssertTrue(app.staticTexts["of 2350 calories"].exists)

    choose(energy: "kJ", in: app)
    // 1,462 kcal × 4.184 = 6,117.008 kJ; 2,350 kcal × 4.184 = 9,832.4 kJ.
    XCTAssertTrue(calories.waitForExistence(timeout: 10))
    XCTAssertEqual(calories.label, "6,117 kilojoules")
    XCTAssertTrue(app.staticTexts["of 9,832.4 kJ"].exists)
    // 2,350 − 1,462 = 888 kcal left, converted after the subtraction: 3,715.4 kJ.
    let balance = app.descendants(matching: .any)["diaryEnergyBalance"].firstMatch
    XCTAssertTrue(balance.label.contains("3,715.4"), balance.label)
    XCTAssertTrue(balance.label.contains("kJ remaining"), balance.label)
    capture("diary-energy-kJ-summary")

    let header = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "diaryMealHeader-")
    ).firstMatch
    reveal(header, in: app)
    XCTAssertTrue(header.label.hasSuffix(" kJ"), header.label)
    XCTAssertFalse(header.label.contains(" cal"), header.label)
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "diaryEntry-"))
      .firstMatch
    reveal(row, in: app)
    XCTAssertTrue(row.label.contains("kJ"), row.label)
    capture("diary-energy-kJ-rows")

    // Copy preview rows and total.
    row.press(forDuration: 1)
    app.buttons["Repeat This Meal"].tap()
    let total = app.staticTexts["copyCalories"]
    reveal(total, in: app)
    XCTAssertTrue(total.label.hasSuffix(" kJ"), total.label)
    XCTAssertFalse(total.label.contains("calories"), total.label)
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "copyFood-"))
        .firstMatch.exists)
    XCTAssertEqual(app.descendants(matching: .any).matching(oldCalorieLabel).count, 0)
    app.navigationBars["Copy Foods"].buttons["Cancel"].tap()

    // Food search rows (recent and saved foods in the fixture).
    let add = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "diaryAdd-"))
      .firstMatch
    reveal(add, in: app)
    add.tap()
    let searchEnergy = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "recent-")
    ).firstMatch
    reveal(searchEnergy, in: app)
    XCTAssertTrue(searchEnergy.label.contains("kJ"), searchEnergy.label)
    XCTAssertFalse(searchEnergy.label.contains("cal"), searchEnergy.label)
    XCTAssertEqual(app.descendants(matching: .any).matching(oldCalorieLabel).count, 0)
    capture("food-search-energy-kJ")
    dismissSheet(in: app)

    // Back to kcal: the stored values were never rewritten.
    choose(energy: "kcal", in: app)
    XCTAssertTrue(calories.waitForExistence(timeout: 10))
    XCTAssertEqual(calories.label, "1462 calories")
    XCTAssertTrue(app.staticTexts["of 2350 calories"].exists)
    reveal(row, in: app)
    XCTAssertTrue(row.label.contains("kcal"), row.label)
  }
}
