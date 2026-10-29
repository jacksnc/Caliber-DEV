import XCTest

/// End-to-end verification for the Pass 2 food-entry workspace:
/// top recents + right-side quick review, backdated meal/date forwarding across routes,
/// honest manual-entry validation without invented zero macros, and Graphite/Frost/AX5 audits.
final class FoodEntryPass2UITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor
  private func launch(
    theme: String = "graphite",
    largeText: Bool = false,
    foodReuseFixture: Bool = true
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--progress-ui-testing",
      "--theme-\(theme)",
    ]
    if foodReuseFixture {
      app.launchArguments.append("--food-reuse-fixture")
    }
    if largeText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName",
        "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    XCTAssertTrue(app.tab("Fuel").waitForExistence(timeout: 20))
    return app
  }

  @MainActor
  private func reveal(
    _ element: XCUIElement,
    in app: XCUIApplication,
    towardTop: Bool = false
  ) {
    for _ in 0..<16 {
      let top =
        app.navigationBars.firstMatch.exists
        ? app.navigationBars.firstMatch.frame.maxY + 8
        : 72
      let bottom: CGFloat
      if app.keyboards.firstMatch.exists {
        bottom = app.keyboards.firstMatch.frame.minY - 8
      } else if app.otherElements["caliberTabBar"].exists
        && app.otherElements["caliberTabBar"].isHittable
      {
        bottom = app.otherElements["caliberTabBar"].frame.minY - 8
      } else {
        bottom = app.windows.firstMatch.frame.maxY - 24
      }
      if element.exists && element.isHittable && element.frame.minY >= top
        && element.frame.maxY <= bottom
      {
        return
      }
      let middle = top + max(20, bottom - top) / 2
      let scrollDown = element.exists ? element.frame.minY < top : towardTop
      let delta = (scrollDown ? 1.0 : -1.0) * min(120, max(20, bottom - top) / 3)
      let origin = app.coordinate(withNormalizedOffset: .zero)
      origin.withOffset(CGVector(dx: 12, dy: middle)).press(
        forDuration: 0.05,
        thenDragTo: origin.withOffset(CGVector(dx: 12, dy: middle + delta))
      )
    }
    XCTAssertTrue(element.isHittable, "Could not reveal \(element)")
  }

  @MainActor
  private func replace(_ field: XCUIElement, with text: String) {
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
    let prior = field.value as? String ?? ""
    if !prior.isEmpty && prior != field.placeholderValue {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count + 1))
    }
    if let remaining = field.value as? String,
      !remaining.isEmpty && remaining != field.placeholderValue
    {
      field.doubleTap()
      field.typeText(XCUIKeyboardKey.delete.rawValue)
    }
    field.typeText(text)
  }

  @MainActor
  private func dismissModalSheet(in app: XCUIApplication) {
    let navBar = app.navigationBars.firstMatch
    XCTAssertTrue(navBar.waitForExistence(timeout: 5))
    let start = navBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
    start.press(forDuration: 0.05, thenDragTo: end)
  }

  @MainActor
  private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testRecentQuickActionPrefillsLastPortionCancelsCleanlyAndKeepsLoggedSnapshotEditable() {
    let app = launch()
    app.tab("Fuel").tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "100.25 calories")

    let addDinner = app.buttons["diaryAdd-dinner"]
    reveal(addDinner, in: app)
    addDinner.tap()

    let summary = app.staticTexts["foodEntryContextSummary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 5))
    XCTAssertTrue(summary.label.contains("Dinner"))

    // Recent foods sit near the top of All Foods with an independent right-side quick review button.
    let quickButton = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@",
        "foodEntryQuickReview-recent-",
        "Quick review Fictional breakfast"
      )
    ).firstMatch
    XCTAssertTrue(quickButton.waitForExistence(timeout: 8))
    reveal(quickButton, in: app)
    quickButton.tap()

    // Prefills last-used 0.5 portion; canceling writes nothing.
    XCTAssertEqual(app.textFields["savedFoodQuantity"].value as? String, "0.5")
    XCTAssertEqual(app.staticTexts["savedFoodCalories"].label, "100.25 calories")
    app.buttons["foodEntryQuickReviewClose"].tap()
    XCTAssertTrue(app.buttons["openBarcode"].waitForExistence(timeout: 5))

    // Reopen quick review, adjust macros for this log only, and confirm once.
    reveal(quickButton, in: app)
    quickButton.tap()
    let adjust = app.switches["Adjust macros for this log"]
    reveal(adjust, in: app)
    adjust.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    let caloriesField = app.textFields["Calories"]
    reveal(caloriesField, in: app)
    replace(caloriesField, with: "300")
    app.buttons["savedFoodKeyboardDone"].tap()
    reveal(app.staticTexts["savedFoodCalories"], in: app, towardTop: true)
    XCTAssertEqual(app.staticTexts["savedFoodCalories"].label, "150 calories")

    app.buttons["savedFoodAdd"].tap()
    XCTAssertFalse(app.buttons["savedFoodAdd"].isEnabled)
    reveal(app.staticTexts["Added to Dinner"], in: app)
    XCTAssertTrue(app.staticTexts["Added to Dinner"].exists)
    app.buttons["foodEntryQuickReviewClose"].tap()

    // Original recent food retains its unedited 200.5 cal/serving reference (0.5 × 200.5 = 100.25 cal).
    reveal(quickButton, in: app)
    quickButton.tap()
    XCTAssertEqual(app.staticTexts["savedFoodCalories"].label, "100.25 calories")
    app.buttons["foodEntryQuickReviewClose"].tap()

    // Dismiss the food-entry workspace back to Diary and verify post-log macro editing.
    dismissModalSheet(in: app)
    reveal(app.staticTexts["diaryCalories"], in: app, towardTop: true)
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "250.25 calories")

    let editedEntry = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
        "diaryEntry-",
        "Fictional breakfast (edited)"
      )
    ).firstMatch
    reveal(editedEntry, in: app)
    editedEntry.tap()

    let postLogCalories = app.textFields["Calories"]
    XCTAssertTrue(postLogCalories.waitForExistence(timeout: 5))
    replace(postLogCalories, with: "320")
    app.buttons["Save"].tap()

    reveal(app.staticTexts["diaryCalories"], in: app, towardTop: true)
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "260.25 calories")
  }

  @MainActor
  func testBackdatedMealCarriesThroughNoResultsManualEntryAndRecipesWithoutInventingZeroMacros() {
    let app = launch(foodReuseFixture: false)
    app.tab("Fuel").tap()

    // Select the 15th of the previous month so the diary is unambiguously backdated on any day.
    let datePicker = app.datePickers["diaryDate"]
    XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
    datePicker.tap()
    let previousMonth = app.buttons["Previous Month"]
    XCTAssertTrue(previousMonth.waitForExistence(timeout: 5))
    previousMonth.tap()
    let day15 = app.buttons.matching(NSPredicate(format: "label CONTAINS '15'")).firstMatch
    XCTAssertTrue(day15.waitForExistence(timeout: 5))
    day15.tap()
    // Dismiss the calendar popover by tapping the header region.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.12)).tap()

    let addDinner = app.buttons["diaryAdd-dinner"]
    reveal(addDinner, in: app)
    addDinner.tap()

    // Backdated badge and Dinner context carry into FoodSearchView.
    XCTAssertTrue(app.staticTexts["Past date"].waitForExistence(timeout: 5))

    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("Unicorn Skillet\n")

    // Switching scopes preserves the typed search text and offers Search All Foods + Create Food.
    let scopePicker = app.buttons["foodSearchScope"]
    reveal(scopePicker, in: app, towardTop: true)
    scopePicker.tap()
    app.buttons["Recent"].tap()
    XCTAssertEqual(search.value as? String, "Unicorn Skillet")

    let showAll = app.buttons["foodSearchEmptyShowAll"]
    XCTAssertTrue(showAll.waitForExistence(timeout: 5))
    showAll.tap()
    XCTAssertEqual(search.value as? String, "Unicorn Skillet")

    let createFromEmpty = app.buttons["foodSearchEmptyCreateFood"]
    XCTAssertTrue(createFromEmpty.waitForExistence(timeout: 8))
    reveal(createFromEmpty, in: app)
    createFromEmpty.tap()

    // Name is prefilled; entering calories alone does NOT invent zero macros.
    let nameField = app.textFields["manualFoodName"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    XCTAssertEqual(nameField.value as? String, "Unicorn Skillet")

    let manualCalories = app.textFields["Calories"]
    manualCalories.tap()
    manualCalories.typeText("250")
    app.buttons["manualFoodKeyboardDone"].tap()
    XCTAssertFalse(app.buttons["manualFoodSave"].isEnabled)

    // Cancel writes nothing.
    app.buttons["manualFoodCancel"].tap()
    XCTAssertTrue(createFromEmpty.waitForExistence(timeout: 5))

    // Reopen manual entry, enter all four macros (with explicit 0 carbs), and save to backdated Dinner.
    createFromEmpty.tap()
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    for (fieldName, value) in [
      ("Calories", "250"),
      ("Protein", "25"),
      ("Carbs", "0"),
      ("Fat", "12"),
    ] {
      let field = app.textFields[fieldName]
      reveal(field, in: app)
      field.tap()
      field.typeText(value)
    }
    app.buttons["manualFoodKeyboardDone"].tap()
    XCTAssertTrue(app.buttons["manualFoodSave"].isEnabled)
    app.buttons["manualFoodSave"].tap()
    reveal(app.staticTexts["Added to Dinner"], in: app)
    XCTAssertTrue(app.staticTexts["Added to Dinner"].exists)
    app.buttons["manualFoodCancel"].tap()

    // Clear search and verify Meals shortcut forwards backdated Dinner into SavedMealDetailView.
    if search.buttons["Clear text"].exists {
      search.buttons["Clear text"].tap()
    }
    if app.buttons["Cancel"].exists && app.searchFields.firstMatch.exists {
      app.buttons["Cancel"].tap()
    }
    let openMeals = app.buttons["foodEntryOpenMyMeals"]
    reveal(openMeals, in: app, towardTop: true)
    openMeals.tap()

    XCTAssertTrue(app.buttons["createRecipe"].waitForExistence(timeout: 5))
    app.buttons["createRecipe"].tap()
    replace(app.textFields["recipeName"], with: "Backdated Stew")
    app.buttons["recipeAddIngredient"].tap()
    let savedIngredient = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
        "recipeIngredientSaved-",
        "Unicorn Skillet"
      )
    ).firstMatch
    XCTAssertTrue(savedIngredient.waitForExistence(timeout: 5))
    savedIngredient.tap()
    app.buttons["ingredientAdd"].tap()
    app.buttons["recipeSave"].tap()

    let savedRecipe = app.buttons["savedRecipe-Backdated Stew"]
    XCTAssertTrue(savedRecipe.waitForExistence(timeout: 5))
    savedRecipe.tap()
    app.buttons["recipeLog"].tap()
    XCTAssertFalse(app.buttons["recipeLog"].isEnabled)
    reveal(app.staticTexts["Added to Dinner"], in: app)
    XCTAssertTrue(app.staticTexts["Added to Dinner"].exists)

    // Dismiss sheet and verify both items landed on the backdated day (250 + 250 = 500 cal).
    dismissModalSheet(in: app)
    reveal(app.staticTexts["diaryCalories"], in: app, towardTop: true)
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "500 calories")
  }

  @MainActor
  func testFutureLoggingDateShowsFutureBadgeNeverPastDateAndRetainsSelectedMealAndDay() {
    let app = launch(foodReuseFixture: true)
    app.tab("Fuel").tap()
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "100.25 calories")

    // Select the 15th of the next month so the target day is unambiguously in the future.
    let datePicker = app.datePickers["diaryDate"]
    XCTAssertTrue(datePicker.waitForExistence(timeout: 5))
    datePicker.tap()
    let nextMonth = app.buttons["Next Month"]
    XCTAssertTrue(nextMonth.waitForExistence(timeout: 5))
    nextMonth.tap()
    let day15 = app.buttons.matching(NSPredicate(format: "label CONTAINS '15'")).firstMatch
    XCTAssertTrue(day15.waitForExistence(timeout: 5))
    day15.tap()
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.12)).tap()

    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "0 calories")

    let addBreakfast = app.buttons["diaryAdd-breakfast"]
    reveal(addBreakfast, in: app)
    addBreakfast.tap()

    // Future dates must show "Future date", never "Past date", while preserving meal and date.
    XCTAssertTrue(app.staticTexts["Future date"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Past date"].exists)
    let contextSummary = app.staticTexts["foodEntryContextSummary"]
    XCTAssertTrue(contextSummary.exists)
    XCTAssertTrue(
      contextSummary.label.hasPrefix("Logging to Breakfast · ")
        && contextSummary.label.contains("15"),
      "Unexpected future context label: \(contextSummary.label)"
    )

    // Quick-log the recent food (last-used 0.5 portion = 100.25 cal) onto future Breakfast.
    let quickButton = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "foodEntryQuickReview-recent-")
    ).firstMatch
    XCTAssertTrue(quickButton.waitForExistence(timeout: 5))
    reveal(quickButton, in: app)
    quickButton.tap()

    XCTAssertEqual(app.textFields["savedFoodQuantity"].value as? String, "0.5")
    app.buttons["savedFoodAdd"].tap()
    XCTAssertFalse(app.buttons["savedFoodAdd"].isEnabled)
    reveal(app.staticTexts["Added to Breakfast"], in: app)
    XCTAssertTrue(app.staticTexts["Added to Breakfast"].exists)
    app.buttons["foodEntryQuickReviewClose"].tap()

    dismissModalSheet(in: app)
    reveal(app.staticTexts["diaryCalories"], in: app, towardTop: true)
    XCTAssertEqual(app.staticTexts["diaryCalories"].label, "100.25 calories")
  }

  @MainActor
  func testGraphiteFrostAndLargestTextAuditsOnFoodEntryWorkspace() throws {
    for (theme, largeText) in [("graphite", false), ("frost", false), ("graphite", true)] {
      let app = launch(theme: theme, largeText: largeText, foodReuseFixture: true)
      app.tab("Fuel").tap()
      let addBreakfast = app.buttons["diaryAdd-breakfast"]
      reveal(addBreakfast, in: app)
      addBreakfast.tap()

      XCTAssertTrue(app.buttons["openBarcode"].waitForExistence(timeout: 8))
      let suffix = "\(theme)-\(largeText ? "AX5" : "default")"
      let auditTypes: XCUIAccessibilityAuditType =
        largeText ? [.dynamicType, .textClipped] : [.textClipped]

      capture("pass2-food-hub-\(suffix)", app: app)
      try app.auditRepeatedIssues(for: auditTypes)

      let manual = app.buttons["foodSearchManual"]
      reveal(manual, in: app)
      manual.tap()
      XCTAssertTrue(app.textFields["manualFoodName"].waitForExistence(timeout: 5))
      capture("pass2-manual-entry-\(suffix)", app: app)
      try app.auditRepeatedIssues(for: auditTypes)
      app.buttons["manualFoodCancel"].tap()

      if !largeText {
        let quickButton = app.buttons.matching(
          NSPredicate(format: "identifier BEGINSWITH %@", "foodEntryQuickReview-recent-")
        ).firstMatch
        reveal(quickButton, in: app)
        quickButton.tap()
        XCTAssertTrue(app.textFields["savedFoodQuantity"].waitForExistence(timeout: 5))
        capture("pass2-quick-review-\(suffix)", app: app)
        try app.auditRepeatedIssues(for: auditTypes)
        app.buttons["foodEntryQuickReviewClose"].tap()
      }

      app.terminate()
    }
  }
}
