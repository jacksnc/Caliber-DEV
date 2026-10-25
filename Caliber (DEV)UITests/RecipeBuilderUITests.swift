import XCTest

/// The recipe flow is exercised against the isolated in-memory store only.
final class RecipeBuilderUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"]
    app.launch()
    app.openFoodLibrary()
    app.buttons["openMyMeals"].tap()
    XCTAssertTrue(app.buttons["createRecipe"].waitForExistence(timeout: 8))
    return app
  }

  @MainActor private func replace(_ field: XCUIElement, with value: String) {
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    let prior = field.value as? String ?? ""
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count) + value)
  }

  @MainActor func testCreateMeasuredRecipeAndLogOneCookedPortion() {
    let app = launch()
    app.buttons["createRecipe"].tap()
    replace(app.textFields["recipeName"], with: "Test Chicken Batch")
    app.buttons["recipeAddIngredient"].tap()
    app.buttons["recipeManualIngredient"].tap()
    replace(app.textFields["recipeIngredientName"], with: "Chicken")
    replace(app.textFields["recipeIngredientServing"], with: "100 g raw")
    for (identifier, value) in [
      ("recipeIngredientCalories", "100"),
      ("recipeIngredientProtein", "20"),
      ("recipeIngredientCarbs", "0"),
      ("recipeIngredientFat", "2"),
    ] {
      replace(app.textFields[identifier], with: value)
      if identifier == "recipeIngredientCarbs" || identifier == "recipeIngredientFat" {
        // Dismiss the decimal pad so lower fields remain reachable.
        app.buttons["recipeIngredientKeyboardDone"].tap()
      }
    }
    app.swipeUp()
    replace(app.textFields["recipeIngredientQuantity"], with: "2")
    app.buttons["recipeIngredientKeyboardDone"].tap()
    let add = app.buttons["ingredientAdd"]
    XCTAssertTrue(add.waitForExistence(timeout: 5))
    add.tap()
    replace(app.textFields["recipeBatchServings"], with: "2")
    app.buttons["recipeKeyboardDone"].tap()
    replace(app.textFields["recipeCookedGrams"], with: "400")
    app.buttons["recipeKeyboardDone"].tap()
    replace(app.textFields["recipeRawGrams"], with: "500")
    app.buttons["recipeKeyboardDone"].tap()
    app.swipeUp()
    XCTAssertTrue(app.staticTexts["recipeBatchCalories"].label.contains("200"))
    XCTAssertTrue(app.staticTexts["recipePerServingCalories"].label.contains("100"))
    XCTAssertTrue(app.staticTexts["recipeYieldFactor"].label.contains("0.8"))
    app.buttons["recipeSave"].tap()

    let saved = app.buttons["savedRecipe-Test Chicken Batch"]
    XCTAssertTrue(saved.waitForExistence(timeout: 8))
    saved.tap()
    XCTAssertTrue(app.staticTexts["recipePortionCalories"].label.contains("100"))
    app.descendants(matching: .any)["recipePortionUnit"].tap()
    app.buttons["Cooked grams"].tap()
    replace(app.textFields["recipePortionAmount"], with: "200")
    app.buttons["recipeKeyboardDone"].tap()
    XCTAssertTrue(app.staticTexts["recipePortionCalories"].label.contains("100"))
    app.buttons["recipeLog"].tap()
    XCTAssertFalse(app.buttons["recipeLog"].isEnabled)
    app.swipeUp()
    XCTAssertTrue(app.staticTexts["Added to Lunch"].waitForExistence(timeout: 5))
  }
}
