import XCTest

final class FoodShortcutsUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  @MainActor private func launch(fixture: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"] + (fixture ? ["--food-reuse-fixture"] : [])
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Diary"].waitForExistence(timeout: 20))
    return app
  }
  @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<18 {
      let top = app.navigationBars.firstMatch.frame.maxY + 8
      let bottom =
        app.keyboards.firstMatch.exists
        ? app.keyboards.firstMatch.frame.minY - 8 : app.tabBars.firstMatch.frame.minY - 8
      if element.exists && element.isHittable && element.frame.minY >= top
        && element.frame.maxY <= bottom
      {
        return
      }
      let middle = top + max(20, bottom - top) / 2
      let delta =
        (element.exists && element.frame.minY < top ? 1.0 : -1.0)
        * min(120, max(20, bottom - top) / 3)
      let origin = app.coordinate(withNormalizedOffset: .zero)
      origin.withOffset(CGVector(dx: 10, dy: middle)).press(
        forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 10, dy: middle + delta)))
    }
    XCTAssertTrue(element.isHittable)
  }
  @MainActor private func replace(_ field: XCUIElement, with text: String) {
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
    let prior = field.value as? String ?? ""
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count) + text)
  }
  @MainActor private func show(_ scope: String, in app: XCUIApplication) {
    let picker = app.buttons["foodSearchScope"]
    reveal(picker, in: app)
    picker.tap()
    app.buttons[scope].tap()
  }
  @MainActor private func snapshot(_ name: String, app: XCUIApplication) {
    // Let the navigation animation settle before collecting its final presentation.
    let settled = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in app.navigationBars.firstMatch.frame.minX < 1 }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor func testRecentFavoriteAndFrequentFoodsReuseTheLatestPortion() {
    let app = launch()
    app.tabBars.buttons["Food Library"].tap()
    app.buttons["openFoodSearch"].tap()
    show("Recent", in: app)
    let recent = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "recent-", "Fictional breakfast")
    ).firstMatch
    XCTAssertTrue(recent.waitForExistence(timeout: 5))
    recent.tap()
    XCTAssertEqual(app.textFields["savedFoodQuantity"].value as? String, "0.5")
    app.buttons["savedFoodFavorite"].tap()
    XCTAssertTrue(app.buttons["savedFoodFavorite"].label.contains("Remove Favorite"))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    show("Favorites", in: app)
    let favorite = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "favorite-", "Fictional breakfast"
      )
    ).firstMatch
    XCTAssertTrue(favorite.waitForExistence(timeout: 5))
    favorite.tap()
    app.buttons["savedFoodAdd"].tap()
    XCTAssertFalse(app.buttons["savedFoodAdd"].isEnabled)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    show("Frequent", in: app)
    XCTAssertTrue(app.staticTexts["Logged 3 times"].waitForExistence(timeout: 5))
    snapshot("Recent favorites and repeat-food history", app: app)
    app.tabBars.buttons["Diary"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "200.5 calories")
  }

  @MainActor func testCopyYesterdayLetsYouChooseFoodsAndAddsOnlyOnce() {
    let app = launch()
    app.tabBars.buttons["Diary"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "100.25 calories")
    app.buttons["diaryCopyDay"].tap()
    let total = app.staticTexts["copyCalories"]
    reveal(total, in: app)
    XCTAssertTrue(total.label.contains("500.75"))
    let snack = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "copyFood-", "Fictional snack")
    ).firstMatch
    reveal(snack, in: app)
    snack.tap()
    XCTAssertTrue(total.label.contains("300.75"))
    app.buttons["copyConfirm"].tap()
    XCTAssertFalse(app.buttons["copyConfirm"].isEnabled)
    reveal(app.staticTexts["copySaved"], in: app)
    snapshot("Review and copy a previous day", app: app)
    app.buttons["Done"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "401 calories")
  }

  @MainActor func testSameDayMealRepeatKeepsItsCompletedPreviewStable() {
    let app = launch()
    app.tabBars.buttons["Diary"].tap()
    let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "diaryEntry-"))
      .firstMatch
    reveal(row, in: app)
    row.press(forDuration: 1)
    app.buttons["Repeat This Meal"].tap()
    let total = app.staticTexts["copyCalories"]
    reveal(total, in: app)
    XCTAssertEqual(total.label, "1 food · 100.25 calories")
    app.buttons["copyConfirm"].tap()
    reveal(app.staticTexts["copySaved"], in: app)
    XCTAssertEqual(total.label, "1 food · 100.25 calories")
    XCTAssertFalse(app.buttons["copyConfirm"].isEnabled)
    app.buttons["Done"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "200.5 calories")
  }

  @MainActor func testOuncesSourcePortionsAndMacroEditsPreserveSelectedMass() {
    let app = launch(fixture: false)
    app.tabBars.buttons["Diary"].tap()
    let add = app.buttons["diaryAdd-breakfast"]
    reveal(add, in: app)
    add.tap()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("oats rolled\n")
    let oats = app.buttons["catalogFood-2346396"]
    XCTAssertTrue(oats.waitForExistence(timeout: 5))
    oats.tap()
    let favorite = app.buttons["referenceFavorite"]
    XCTAssertTrue(favorite.waitForExistence(timeout: 5))
    favorite.tap()
    XCTAssertTrue(favorite.label.contains("Remove Favorite"))
    app.buttons["referenceUnit"].tap()
    app.buttons["oz"].tap()
    replace(app.textFields["referenceOunces"], with: "4")
    app.buttons["nutritionKeyboardDone"].tap()
    XCTAssertTrue(app.staticTexts["referenceCalories"].label.hasPrefix("429.77"))
    app.buttons["referenceUnit"].tap()
    app.buttons["Portions"].tap()
    replace(app.textFields["referenceQuantity"], with: "2")
    app.buttons["nutritionKeyboardDone"].tap()
    XCTAssertEqual(app.staticTexts["referenceCalories"].label, "758 calories")
    let adjust = app.switches["Adjust macros for this log"]
    reveal(adjust, in: app)
    adjust.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    let calories = app.textFields["Calories"]
    reveal(calories, in: app)
    replace(calories, with: "800.5")
    app.buttons["nutritionKeyboardDone"].tap()
    reveal(app.buttons["referenceUnit"], in: app)
    app.buttons["referenceUnit"].tap()
    app.buttons["g"].tap()
    XCTAssertEqual(app.textFields["referenceGrams"].value as? String, "200")
    XCTAssertEqual(app.staticTexts["referenceCalories"].label, "800.5 calories")
    app.buttons["referenceAdd"].tap()
    XCTAssertFalse(app.buttons["referenceAdd"].isEnabled)
    reveal(app.staticTexts["referenceSaved"], in: app)
    XCTAssertTrue(app.staticTexts["referenceSaved"].label.contains("Breakfast"))
    snapshot("Source portion and personal macro review", app: app)
  }
}
