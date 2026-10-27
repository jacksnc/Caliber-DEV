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
        XCTAssertTrue(app.staticTexts["Progress integration check"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["latestProgressWeight"].exists)

        // Today's + opens the same check-in; canceling a draft preserves the log.
        app.buttons["addProgressEntry"].tap()
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
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "progressEntry-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // Scroll the row clear of the floating tab bar first, as a person would.
        let tabBar = app.descendants(matching: .any)["caliberTabBar"]
        for _ in 0..<8 {
            let limit = tabBar.exists ? tabBar.frame.minY : app.frame.maxY
            if row.isHittable && row.frame.maxY < limit && row.frame.minY > 120 { break }
            // Short drags, so the row cannot overshoot past the top.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let distance: CGFloat = row.frame.minY <= 120 ? 180 : -180
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
        // The swipe does nothing while the check-in sheet is still closing.
        let edit = app.buttons["Edit"]
        for _ in 0..<3 where !edit.exists {
            row.swipeLeft()
            _ = edit.waitForExistence(timeout: 2)
        }
        edit.tap()
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.replaceText("179.25")
        save.tap()
        XCTAssertTrue(app.staticTexts["latestProgressWeight"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["latestProgressWeight"].label.contains("179.25"))
        XCTAssertEqual(app.cells.containing(.staticText, identifier: "Progress integration check").count, 1)

        row.swipeLeft()
        app.buttons["Delete"].tap()
        app.alerts["Delete Check-In?"].buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Progress integration check"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["latestProgressWeight"].exists)
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
        XCTAssertTrue(app.staticTexts["Notes-only check-in"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["latestProgressWeight"].exists)
        app.cells.containing(.staticText, identifier: "Notes-only check-in").firstMatch.tap()
        XCTAssertTrue(app.buttons["editProgressEntry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Notes-only check-in"].exists)
    }
}
