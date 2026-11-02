import XCTest

final class ProgressUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor
  private func openProgress() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--progress-ui-testing"]
    app.launch()
    let progress = app.tab("Progress")
    XCTAssertTrue(progress.waitForExistence(timeout: 20))
    progress.tap()
    return app
  }

  @MainActor
  private func scrollList(in app: XCUIApplication) -> XCUIElement {
    let collection = app.collectionViews.firstMatch
    return collection.exists ? collection : app.scrollViews.firstMatch
  }

  /// Reveal a lazy timeline row without dragging across the floating tab bar.
  @MainActor
  private func reveal(
    _ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false
  ) {
    let list = scrollList(in: app)
    let tabBar = app.otherElements["caliberTabBar"]
    XCTAssertTrue(list.exists)
    XCTAssertTrue(tabBar.exists)
    for _ in 0..<12 {
      if element.exists {
        let frame = element.frame
        if element.isHittable && frame.maxY < tabBar.frame.minY - 8 { return }
        if frame.minY < 88 {
          list.swipeDown()
        } else {
          list.swipeUp()
        }
      } else if towardTop {
        list.swipeDown()
      } else {
        list.swipeUp()
      }
    }
    let frame = element.exists ? "\(element.frame)" : "unavailable"
    let tabBarFrame = tabBar.exists ? "\(tabBar.frame)" : "unavailable"
    let diagnostics =
      "Progress reveal: id=\(element.identifier), exists=\(element.exists), "
      + "hittable=\(element.isHittable), frame=\(frame), "
      + "list=\(list.frame), tabBar=\(tabBarFrame)\n"
      + app.debugDescription
    let attachment = XCTAttachment(string: diagnostics)
    attachment.name = "Progress timeline reveal hierarchy"
    attachment.lifetime = .keepAlways
    add(attachment)
    XCTFail("Could not reveal \(element)")
  }

  @MainActor
  private func timelineRow(in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "progressEntry-")).firstMatch
  }

  /// Decimal-pad fields do not reliably show the Select All menu. Put the caret at
  /// the trailing edge before clearing so deletion always removes the saved value.
  @MainActor
  private func replaceWeight(_ field: XCUIElement, with value: String) {
    let trailingEdge = field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
    trailingEdge.tap()
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 24))
    field.typeText(value)
  }

  /// V2: the weight chart has a text alternative listing each recorded weigh-in.
  @MainActor
  func testWeightChartListsWeighInsAsText() {
    let app = openProgress()
    app.buttons["addProgressEntry"].tap()
    let weight = app.textFields["progressWeight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    weight.tap()
    weight.typeText("181.5")
    app.buttons["progressSave"].tap()
    let readings = app.buttons["weightTrendReadings"]
    XCTAssertTrue(readings.waitForExistence(timeout: 5))
    // The table adds one dated row per weigh-in to what the chart card already shows.
    let year = String(Calendar.current.component(.year, from: .now))
    let dated = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "181.5", year))
    let before = dated.count
    XCTAssertEqual(readings.value as? String, "Hidden")
    readings.tap()
    XCTAssertEqual(readings.value as? String, "Shown")
    XCTAssertGreaterThan(dated.count, before)
    readings.tap()
    XCTAssertEqual(readings.value as? String, "Hidden")
    XCTAssertEqual(dated.count, before)
  }

  @MainActor
  func testDailyCheckInEditsSameDayAndCanBeDeleted() {
    let app = openProgress()
    app.buttons["addProgressEntry"].tap()
    let save = app.buttons["progressSave"]
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    XCTAssertFalse(save.isEnabled)

    let weight = app.textFields["progressWeight"]
    weight.tap()
    weight.typeText("180.5")
    let notes = app.textViews["progressNotes"]
    notes.tap()
    notes.typeText("Progress integration check")
    save.tap()
    let row = timelineRow(in: app)
    reveal(row, in: app)
    XCTAssertTrue(app.staticTexts["Progress integration check"].waitForExistence(timeout: 5))
    // The combined chart value is exposed as an accessibility element, not a StaticText.
    let latestWeight = app.descendants(matching: .any)["latestProgressWeight"]
    reveal(latestWeight, in: app, towardTop: true)
    XCTAssertTrue(latestWeight.exists)

    // Today's + opens the same check-in; canceling a draft preserves the log.
    let add = app.buttons["addProgressEntry"]
    reveal(add, in: app, towardTop: true)
    add.tap()
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    XCTAssertEqual(notes.value as? String, "Progress integration check")
    notes.tap()
    notes.typeText(" discarded draft")
    app.buttons["Cancel"].tap()
    app.buttons["addProgressEntry"].tap()
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    XCTAssertEqual(notes.value as? String, "Progress integration check")
    app.buttons["Cancel"].tap()

    // The timeline row's own link, not the first cell that mentions the note.
    reveal(row, in: app)
    // The swipe does nothing while the check-in sheet is still closing.
    let edit = app.buttons["Edit"]
    for _ in 0..<3 where !edit.exists {
      row.swipeLeft()
      _ = edit.waitForExistence(timeout: 2)
    }
    edit.tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    replaceWeight(weight, with: "179.25")
    save.tap()
    reveal(latestWeight, in: app, towardTop: true)
    XCTAssertTrue(latestWeight.waitForExistence(timeout: 5))
    XCTAssertTrue(latestWeight.label.contains("179.25"))
    reveal(row, in: app)
    XCTAssertEqual(
      app.cells.containing(.staticText, identifier: "Progress integration check").count, 1)

    row.swipeLeft()
    app.buttons["Delete"].tap()
    app.alerts["Delete Check-In?"].buttons["Delete"].tap()
    XCTAssertTrue(app.staticTexts["Progress integration check"].waitForNonExistence(timeout: 5))
    XCTAssertFalse(app.descendants(matching: .any)["latestProgressWeight"].exists)
  }

  @MainActor
  func testNotesOnlyCheckInDoesNotInventAWeight() {
    let app = openProgress()
    app.buttons["addProgressEntry"].tap()
    let notes = app.textViews["progressNotes"]
    XCTAssertTrue(notes.waitForExistence(timeout: 5))
    notes.tap()
    notes.typeText("Notes-only check-in")
    app.buttons["progressSave"].tap()
    let row = timelineRow(in: app)
    reveal(row, in: app)
    XCTAssertTrue(app.staticTexts["Notes-only check-in"].waitForExistence(timeout: 5))
    reveal(app.screenTitle("Progress"), in: app, towardTop: true)
    XCTAssertFalse(app.descendants(matching: .any)["latestProgressWeight"].exists)
    reveal(row, in: app)
    app.cells.containing(.staticText, identifier: "Notes-only check-in").firstMatch.tap()
    XCTAssertTrue(app.buttons["editProgressEntry"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Notes-only check-in"].exists)
  }
}
