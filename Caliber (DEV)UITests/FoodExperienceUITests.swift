import XCTest

/// All nutrition and menu checks run in an isolated in-memory personal store.
final class FoodExperienceUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  @MainActor private func launch(barcodeFixture: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"] + (barcodeFixture ? ["--barcode-fixture"] : [])
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Food Library"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Food Library"].tap()
    return app
  }
  @MainActor private func reveal(
    _ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false
  ) {
    for _ in 0..<14 {
      let top = app.navigationBars.firstMatch.frame.maxY + 8
      let bottom =
        app.keyboards.firstMatch.exists
        ? app.keyboards.firstMatch.frame.minY - 8 : app.tabBars.firstMatch.frame.minY - 8
      if element.exists && element.isHittable && element.frame.minY >= top
        && element.frame.maxY <= bottom
      {
        return
      }
      // Short drags stay inside visible form content and cannot skip a row
      // from below the keyboard to underneath the navigation bar.
      let middle = top + max(20, bottom - top) / 2
      let distance = min(120, max(20, bottom - top) / 3)
      let scrollDown = element.exists ? element.frame.minY < top : towardTop
      let delta = scrollDown ? distance : -distance
      let start = app.coordinate(withNormalizedOffset: .zero).withOffset(
        CGVector(dx: 10, dy: middle))
      let end = app.coordinate(withNormalizedOffset: .zero).withOffset(
        CGVector(dx: 10, dy: middle + delta))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
    XCTAssertTrue(element.isHittable, "Could not reveal \(element.identifier): \(element.frame)")
  }
  @MainActor private func replace(_ field: XCUIElement, with value: String) {
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
    let previous = field.value as? String ?? ""
    field.typeText(
      String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + value)
  }
  @MainActor private func snapshot(_ name: String, app: XCUIApplication) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  @MainActor func testOfflineFoodPortionAndPersonalMacroEditCanBeLogged() {
    let app = launch()
    app.buttons["openFoodSearch"].tap()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("bananas\n")
    let result = app.buttons["catalogFood-1105073"]
    XCTAssertTrue(result.waitForExistence(timeout: 8))
    result.tap()
    XCTAssertTrue(app.staticTexts["referenceFoodName"].waitForExistence(timeout: 5))
    replace(app.textFields["referenceGrams"], with: "150")
    app.buttons["nutritionKeyboardDone"].tap()
    XCTAssertEqual(app.textFields["referenceGrams"].value as? String, "150")
    XCTAssertTrue(
      app.staticTexts["referenceCalories"].label.contains("127.5"),
      app.staticTexts["referenceCalories"].label)
    let adjust = app.switches["Adjust macros for this log"]
    reveal(adjust, in: app)
    adjust.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    let calories = app.textFields["Calories"]
    reveal(calories, in: app)
    replace(calories, with: "200.5")
    app.buttons["nutritionKeyboardDone"].tap()
    app.buttons["referenceAdd"].tap()
    XCTAssertFalse(app.buttons["referenceAdd"].isEnabled)
    reveal(app.staticTexts["referenceSaved"], in: app)
    XCTAssertTrue(app.staticTexts["referenceSaved"].exists)
    snapshot("USDA food logged with personal macros", app: app)
  }

  @MainActor func testBarcodeManualCaptureConsentAndFictionalProductReview() {
    let app = launch(barcodeFixture: true)
    app.buttons["openBarcode"].tap()
    app.buttons["barcodeOpenCamera"].tap()
    let input = app.textFields["barcodeManualInput"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    input.tap()
    input.typeText("123")
    app.buttons["barcodeConfirm"].tap()
    XCTAssertTrue(app.staticTexts["barcodeValidationMessage"].waitForExistence(timeout: 3))
    replace(input, with: "012345678905")
    app.buttons["barcodeConfirm"].tap()
    XCTAssertTrue(app.textFields["barcodeLookupCode"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["barcodeLookupCode"].value as? String, "012345678905")
    let lookup = app.buttons["barcodeLookup"]
    reveal(lookup, in: app)
    lookup.tap()
    XCTAssertTrue(app.staticTexts["barcodeLookupMessage"].label.contains("Allow online"))
    let permission = app.switches["barcodePermission"]
    reveal(permission, in: app)
    permission.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    lookup.tap()
    let review = app.buttons["barcodeReview"]
    reveal(review, in: app)
    review.tap()
    XCTAssertEqual(app.textFields["referenceGrams"].value as? String, "50")
    XCTAssertTrue(app.staticTexts["referenceCalories"].label.contains("200"))
    snapshot("Fictional barcode product review", app: app)
    app.buttons["referenceAdd"].tap()
    XCTAssertFalse(app.buttons["referenceAdd"].isEnabled)
  }

  @MainActor func testLocalRestaurantCanBeCreatedAndReceivesCustomMenu() {
    let app = launch()
    app.buttons["Restaurants"].tap()
    let add = app.buttons["addRestaurant"]
    XCTAssertTrue(add.waitForExistence(timeout: 10))
    add.tap()
    let name = app.textFields["newRestaurantName"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("QA Local Grill")
    app.buttons["saveRestaurant"].tap()
    let restaurant = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", "QA Local Grill")
    ).firstMatch
    XCTAssertTrue(restaurant.waitForExistence(timeout: 5))
    restaurant.tap()
    app.buttons["Add Custom Item"].tap()
    let food = app.textFields["customMenuItemName"]
    XCTAssertTrue(food.waitForExistence(timeout: 5))
    food.tap()
    food.typeText("Local plate")
    app.textFields["Calories"].tap()
    app.textFields["Calories"].typeText("321.5")
    app.buttons["Save"].tap()
    XCTAssertTrue(app.staticTexts["Local plate"].waitForExistence(timeout: 5))
    snapshot("Local restaurant with personal entree", app: app)
  }

  @MainActor private func openOfflineProduct(_ code: String, in app: XCUIApplication) {
    app.buttons["openBarcode"].tap()
    let input = app.textFields["barcodeLookupCode"]
    XCTAssertTrue(input.waitForExistence(timeout: 20))
    XCTAssertFalse(app.switches["barcodePermission"].exists)
    replace(input, with: code)
    app.buttons["barcodeKeyboardDone"].tap()
    let lookup = app.buttons["barcodeLookup"]
    reveal(lookup, in: app)
    lookup.tap()
    let review = app.buttons["barcodeReview"]
    XCTAssertTrue(review.waitForExistence(timeout: 5))
    reveal(review, in: app)
    review.tap()
  }

  @MainActor func testBundledBarcodeFindsAMassProductWithoutOnlinePermission() {
    let app = launch()
    openOfflineProduct("016000482685", in: app)
    XCTAssertTrue(app.staticTexts["referenceFoodName"].label.contains("CHEERIOS"))
    XCTAssertEqual(app.textFields["referenceGrams"].value as? String, "28")
    reveal(app.staticTexts["referenceCalories"], in: app)
    XCTAssertEqual(app.staticTexts["referenceCalories"].label, "110.04 calories")
    reveal(app.textFields["referenceGrams"], in: app, towardTop: true)
    replace(app.textFields["referenceGrams"], with: "56")
    app.buttons["nutritionKeyboardDone"].tap()
    reveal(app.staticTexts["referenceCalories"], in: app)
    XCTAssertEqual(app.staticTexts["referenceCalories"].label, "220.08 calories")
    snapshot("Offline USDA packaged food with a weighed portion", app: app)
    app.buttons["referenceAdd"].tap()
    XCTAssertFalse(app.buttons["referenceAdd"].isEnabled)
    app.tabBars.buttons["Diary"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "220.08 calories")
  }

  @MainActor func testBundledBarcodeKeepsALiquidServingInMilliliters() {
    let app = launch()
    openOfflineProduct("000020072353", in: app)
    XCTAssertTrue(app.staticTexts["referenceFoodName"].label.contains("CLASSIC ENERGY DRINK"))
    XCTAssertFalse(app.textFields["referenceGrams"].exists)
    XCTAssertFalse(app.buttons["referenceUnit"].exists)
    XCTAssertEqual(app.textFields["referenceQuantity"].value as? String, "1")
    replace(app.textFields["referenceQuantity"], with: "2")
    app.buttons["nutritionKeyboardDone"].tap()
    reveal(app.staticTexts["referenceCalories"], in: app)
    XCTAssertEqual(app.staticTexts["referenceCalories"].label, "220 calories")
    snapshot("Offline USDA volume serving without gram conversion", app: app)
    app.buttons["referenceAdd"].tap()
    XCTAssertFalse(app.buttons["referenceAdd"].isEnabled)
    app.tabBars.buttons["Diary"].tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "220 calories")
  }
  @MainActor func testImportedFictionalMenuUsesCategoriesAndPersonalReview() {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing", "--restaurant-menu-fixture"]
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Food Library"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Food Library"].tap()
    app.buttons["Restaurants"].tap()
    let restaurant = app.buttons["importedRestaurant-fictional-kitchen"]
    XCTAssertTrue(restaurant.waitForExistence(timeout: 10))
    restaurant.tap()
    XCTAssertTrue(app.staticTexts["fictionalMenuNotice"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Entrées"].exists)
    XCTAssertTrue(app.staticTexts["Sides"].exists)
    app.buttons["importedMenu-fictional-chicken"].tap()
    replace(app.textFields["referenceGrams"], with: "100")
    app.buttons["nutritionKeyboardDone"].tap()
    XCTAssertTrue(app.staticTexts["referenceCalories"].label.contains("200"))
    app.buttons["referenceAdd"].tap()
    XCTAssertFalse(app.buttons["referenceAdd"].isEnabled)
    snapshot("Fictional imported menu reviewed and logged", app: app)
  }

}
