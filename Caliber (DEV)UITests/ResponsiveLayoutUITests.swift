import XCTest

/// Real rotations with fictional, in-memory data. No personal simulator or store is used.
final class ResponsiveLayoutUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch(workout: Bool = false, textSize: String? = nil) -> XCUIApplication
  {
    XCUIDevice.shared.orientation = .portrait
    let app = XCUIApplication()
    app.launchArguments = [
      "--progress-ui-testing", "--theme-frost", "--stack-fixture",
      workout ? "--showcase-fixture" : "--food-reuse-fixture",
    ]
    if workout { app.launchArguments.append("--showcase-workout") }
    if let textSize {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", textSize,
      ]
    }
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
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

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    // Application-only crops can retain a portrait transform after rotation.
    // Capture the owned simulator's full screen so all edges remain reviewable.
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor private func scrollContainer(in app: XCUIApplication) -> XCUIElement {
    // Keep a live query across navigation animations; an enumerated index can
    // disappear as the outgoing collection is removed from the hierarchy.
    let list = app.collectionViews.firstMatch
    if list.exists { return list }
    let scroll = app.scrollViews.firstMatch
    return scroll.exists ? scroll : app.windows.firstMatch
  }

  @MainActor private func replace(_ field: XCUIElement, with text: String) {
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    // Center tapping a wide iPad field places the caret mid-value. Place it
    // after the trailing character before clearing, then verify the input now.
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
    let count = (field.value as? String)?.count ?? 0
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count + 2))
    field.typeText(text)
    XCTAssertEqual(field.value as? String, text)
  }

  /// Drag inside the actual list. Global x=10 is outside a centered tablet column.
  @MainActor private func reveal(
    _ element: XCUIElement, app: XCUIApplication, towardTop: Bool = false
  ) {
    for _ in 0..<24 {
      let frame = scrollContainer(in: app).frame
      let nav = app.navigationBars.firstMatch
      let top = max(frame.minY + 12, nav.exists ? nav.frame.maxY + 8 : frame.minY + 12)
      var bottom = frame.maxY - 12
      for boundary in [
        app.keyboards.firstMatch, app.otherElements["foodEntryReviewBar"],
        app.otherElements["caliberTabBar"],
      ] where boundary.exists && boundary.isHittable && boundary.frame.minY > top {
        bottom = min(bottom, boundary.frame.minY - 8)
      }
      let exists = element.exists && !element.frame.isEmpty
      if exists && element.isHittable && element.frame.minY >= top
        && element.frame.maxY <= bottom
      {
        return
      }
      let dy: CGFloat = exists ? (element.frame.minY < top ? 1 : -1) : (towardTop ? 1 : -1)
      let distance = min(160, max(40, (bottom - top) * 0.35))
      // Stay in the list gutter: a drag starting on a wide numeric field can
      // select text instead of scrolling, particularly at accessibility sizes.
      let center = CGPoint(x: frame.minX + 4, y: (top + bottom) / 2)
      let origin = app.coordinate(withNormalizedOffset: .zero)
      origin.withOffset(CGVector(dx: center.x, dy: center.y)).press(
        forDuration: 0.05,
        thenDragTo: origin.withOffset(CGVector(dx: center.x, dy: center.y + dy * distance)),
        withVelocity: .default, thenHoldForDuration: 0.1)
    }
    XCTFail("Could not reveal \(element)")
  }

  @MainActor private func assertVisible(_ element: XCUIElement, app: XCUIApplication) {
    XCTAssertTrue(element.exists)
    XCTAssertTrue(element.isHittable)
    let window = app.windows.firstMatch.frame
    let keyboard = app.keyboards.firstMatch
    let bottom = keyboard.exists ? min(window.maxY, keyboard.frame.minY) : window.maxY
    XCTAssertGreaterThanOrEqual(element.frame.minX, window.minX - 1)
    XCTAssertLessThanOrEqual(element.frame.maxX, window.maxX + 1)
    XCTAssertGreaterThanOrEqual(element.frame.minY, window.minY)
    XCTAssertLessThanOrEqual(element.frame.maxY, bottom + 1)
    XCTAssertGreaterThanOrEqual(element.frame.width, 47.5)
    XCTAssertGreaterThanOrEqual(element.frame.height, 47.5)
  }

  @MainActor func testMainScreensKeepCenteredReadableColumnAcrossRotation() {
    let app = launch(workout: true)
    defer { XCUIDevice.shared.orientation = .portrait }
    for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft] {
      rotate(orientation, app: app)
      for name in ["Today", "Train", "Fuel", "Stack", "Progress"] {
        app.tab(name).tap()
        XCTAssertTrue(app.screenTitle(name).waitForExistence(timeout: 5))
        let bar = app.otherElements["caliberTabBar"]
        XCTAssertTrue(bar.exists)
        XCTAssertLessThanOrEqual(bar.frame.width, 680.5)
        XCTAssertEqual(bar.frame.midX, app.windows.firstMatch.frame.midX, accuracy: 1)
        // Measure the container that owns this heading, not a system pager.
        let collection = app.collectionViews.containing(
          .any, identifier: "screenTitle-" + name
        ).firstMatch
        let scroll = app.scrollViews.containing(
          .any, identifier: "screenTitle-" + name
        ).firstMatch
        let list = collection.exists ? collection : scroll
        XCTAssertTrue(list.exists)
        XCTAssertLessThanOrEqual(list.frame.width, 720.5)
        XCTAssertEqual(list.frame.midX, app.windows.firstMatch.frame.midX, accuracy: 1)
        capture(
          "responsive-frost-\(name)-\(orientation.isLandscape ? "landscape" : "portrait")", app: app
        )
      }
      for tab in ["Today", "Train", "Fuel", "Stack", "Progress"] {
        assertVisible(app.tab(tab), app: app)
      }
    }
  }

  @MainActor func testFoodMealQueryAndFractionalPortionSurviveKeyboardRotation() {
    let app = launch()
    defer { XCUIDevice.shared.orientation = .portrait }
    app.tab("Fuel").tap()
    let add = app.buttons["diaryAdd-breakfast"]
    reveal(add, app: app)
    add.tap()
    let dinner = app.buttons["foodEntryMeal-dinner"]
    reveal(dinner, app: app)
    dinner.tap()
    let context = app.staticTexts["foodEntryContextSummary"].label
    XCTAssertTrue(context.contains("Dinner"))
    let search = app.searchFields.firstMatch
    search.tap()
    search.typeText("Fictional breakfast")
    XCTAssertTrue(app.keyboards.firstMatch.exists)
    rotate(.landscapeLeft, app: app)
    XCTAssertEqual(search.value as? String, "Fictional breakfast")
    XCTAssertEqual(app.staticTexts["foodEntryContextSummary"].label, context)
    search.typeText("\n")
    let quick = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@",
        "foodEntryQuickReview-recent-", "Quick review Fictional breakfast")
    ).firstMatch
    reveal(quick, app: app)
    quick.tap()
    let quantity = app.textFields["savedFoodQuantity"]
    XCTAssertTrue(quantity.waitForExistence(timeout: 5))
    replace(quantity, with: "0.75")
    XCTAssertTrue(app.keyboards.firstMatch.exists)
    rotate(.portrait, app: app)
    XCTAssertEqual(quantity.value as? String, "0.75")
    app.buttons["savedFoodKeyboardDone"].tap()
    let calories = app.staticTexts["savedFoodCalories"]
    reveal(calories, app: app)
    XCTAssertEqual(calories.label, "150.375 calories")
    assertVisible(app.buttons["savedFoodAdd"], app: app)
    assertVisible(app.buttons["foodEntryQuickReviewClose"], app: app)
    capture("responsive-frost-review-portrait-fractional", app: app)
    rotate(.landscapeLeft, app: app)
    XCTAssertEqual(quantity.value as? String, "0.75")
    assertVisible(app.buttons["savedFoodAdd"], app: app)
    capture("responsive-frost-review-landscape-fractional", app: app)
    app.buttons["savedFoodAdd"].tap()
    XCTAssertFalse(app.buttons["savedFoodAdd"].isEnabled)
    let saved = app.staticTexts["savedFoodSaved"]
    reveal(saved, app: app)
    XCTAssertEqual(saved.label, "Added to Dinner")
    app.buttons["foodEntryQuickReviewClose"].tap()
    XCTAssertEqual(search.value as? String, "Fictional breakfast")
    XCTAssertEqual(app.staticTexts["foodEntryContextSummary"].label, context)
    rotate(.portrait, app: app)
    let nav = app.navigationBars.firstMatch
    let start = nav.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
    start.press(forDuration: 0.05, thenDragTo: end)
    XCTAssertTrue(search.waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.tab("Fuel").isHittable)
    let diary = app.staticTexts["diaryCalories"]
    reveal(diary, app: app)
    // Exactly one new snapshot: existing100.25 + (200.5 × 0.75).
    XCTAssertEqual(diary.label, "250.625 calories")
  }

  @MainActor func testWorkoutFractionalDraftSurvivesRotationAndCardCollapse() {
    checkWorkoutDraft(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
  }

  @MainActor func testIntermediateTextWorkoutDraftSurvivesWidthFallback() {
    checkWorkoutDraft(textSize: "UICTContentSizeCategoryXXXL")
  }

  @MainActor private func checkWorkoutDraft(textSize: String) {
    let app = launch(workout: true, textSize: textSize)
    defer { XCUIDevice.shared.orientation = .portrait }
    app.tab("Train").tap()
    app.buttons["resumeWorkout"].tap()
    let firstWeight = app.textFields["Weight"].firstMatch
    reveal(firstWeight, app: app)
    // Keep the same set even when other lazy rows enter/leave the viewport.
    let fieldID = firstWeight.identifier
    XCTAssertTrue(fieldID.hasPrefix("workoutField-"))
    let weight = app.textFields[fieldID]
    let portraitFieldWidth = weight.frame.width
    let compactPhone = app.windows.firstMatch.frame.width < 500
    replace(weight, with: "42.75")
    XCTAssertTrue(app.keyboards.firstMatch.exists)
    rotate(.landscapeLeft, app: app)
    XCTAssertEqual(weight.value as? String, "42.75")
    if compactPhone && textSize == "UICTContentSizeCategoryXXXL" {
      XCTAssertGreaterThan(portraitFieldWidth, weight.frame.width + 20)
    }
    app.buttons["workoutKeyboardDone"].tap()
    // Start from a known position before finding a specific lazy row. Its
    // offscreen identity alone does not tell us which direction to scroll.
    reveal(app.screenTitle("ActiveWorkout"), app: app, towardTop: true)
    let reps = app.textFields[fieldID.replacingOccurrences(of: "-Weight", with: "-Reps")]
    reveal(reps, app: app)
    replace(reps, with: "11")
    app.buttons["workoutKeyboardDone"].tap()
    rotate(.portrait, app: app)
    let bench = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
        "workoutExercise-", "Bench Press")
    ).firstMatch
    reveal(bench, app: app, towardTop: true)
    bench.tap()
    bench.tap()
    reveal(weight, app: app)
    XCTAssertEqual(weight.value as? String, "42.75")
    reveal(reps, app: app)
    XCTAssertEqual(reps.value as? String, "11")
    assertVisible(reps, app: app)
    let suffix = textSize == "UICTContentSizeCategoryXXXL" ? "XXXL" : "AX5"
    capture("responsive-frost-workout-\(suffix)-draft", app: app)
  }
}
