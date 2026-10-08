import XCTest

/// Exercises the actual gestures and forms, in addition to the storage tests.
final class RestaurantCustomizationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openRestaurant(_ name: String, in app: XCUIApplication) {
        let library = app.tabBars.buttons["Food Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 30))
        library.tap()
        app.buttons["Restaurants"].tap()
        let restaurant = app.buttons[name]
        XCTAssertTrue(restaurant.waitForExistence(timeout: 15))
        restaurant.tap()
    }

    @MainActor
    func testCustomMenuItemCanBeAddedEditedAndDeleted() {
        let app = XCUIApplication()
        app.launch()
        openRestaurant("Longhorn Steakhouse", in: app)
        let name = "Test special \(UUID().uuidString.prefix(8))"
        let editedName = name + " revised"

        app.buttons["Add Custom Item"].tap()
        let nameField = app.textFields["customMenuItemName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        let calories = app.textFields["Calories"]
        calories.tap()
        calories.typeText("321.5")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        row.swipeLeft()
        XCTAssertTrue(app.buttons["Edit"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)
        XCTAssertFalse(app.buttons["Double Portion"].exists)
        app.buttons["Edit"].tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: name.count) + editedName)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[editedName].waitForExistence(timeout: 5))

        // Relaunch to prove the custom item and its edits were really saved.
        app.terminate()
        app.launch()
        openRestaurant("Longhorn Steakhouse", in: app)
        XCTAssertTrue(app.staticTexts[editedName].waitForExistence(timeout: 5))
        app.cells.containing(.staticText, identifier: editedName).firstMatch.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts[editedName].waitForNonExistence(timeout: 5))

        // The built-in row still has neither personal-item action.
        app.cells.containing(.staticText, identifier: "6oz Flo's Filet").firstMatch.swipeLeft()
        XCTAssertFalse(app.buttons["Edit"].exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
    }

    @MainActor
    func testChipotleOnlyOffersDoublingForEligibleProtein() {
        let app = XCUIApplication()
        app.launch()
        openRestaurant("Chipotle", in: app)
        app.buttons["Build Your Own Entrée"].tap()
        let bowl = app.buttons["ingredient-Bowl (No Tortilla)"]
        XCTAssertTrue(bowl.waitForExistence(timeout: 5))
        bowl.tap()

        let chicken = app.buttons["ingredient-Chicken"]
        for _ in 0..<5 where !chicken.isHittable { app.swipeUp() }
        XCTAssertTrue(chicken.isHittable)
        chicken.swipeLeft()
        let portion = app.buttons["portion-Chicken"]
        XCTAssertTrue(portion.waitForExistence(timeout: 5))
        XCTAssertTrue(portion.label.contains("Double"))
        portion.tap()
        XCTAssertTrue(chicken.value as? String == "Selected, double portion")
        chicken.swipeLeft()
        XCTAssertTrue(portion.label.contains("Regular"))
        portion.tap()
        XCTAssertTrue(chicken.value as? String == "Selected, regular portion")

        let rice = app.buttons["ingredient-White Rice"]
        for _ in 0..<5 where !rice.isHittable { app.swipeUp() }
        XCTAssertTrue(rice.isHittable)
        rice.swipeLeft()
        XCTAssertFalse(app.buttons["portion-White Rice"].exists)
    }
}
