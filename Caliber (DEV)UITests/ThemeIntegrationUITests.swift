import XCTest

/// Screenshots and accessibility checks exercise real routes with isolated test data.
final class ThemeIntegrationUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = true }

  @MainActor private func launch(
    theme: String, largeText: Bool = false, showcase: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--progress-ui-testing", "--theme-\(theme)", "--barcode-fixture", "--stack-fixture",
    ]
    // Filled, fictional data so screenshots compare with the look book's populated boards.
    if showcase { app.launchArguments.append("--showcase-fixture") }
    if largeText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    return app
  }

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor private func audit(_ app: XCUIApplication, largeText: Bool) throws {
    // Starting at AX5 keeps growing lazy-list rows from disappearing mid-audit.
    // Default-size clipping is checked separately; text growth is measured below.
    let types: XCUIAccessibilityAuditType =
      largeText ? [.dynamicType, .textClipped] : [.textClipped]
    try app.auditRepeatedIssues(for: types)
  }

  @MainActor private func inspect(theme: String, largeText: Bool = false) throws {
    let app = launch(theme: theme, largeText: largeText, showcase: true)
    for tab in ["Today", "Train", "Fuel", "Stack", "Progress"] {
      app.tab(tab).tap()
      XCTAssertTrue(app.screenTitle(tab).waitForExistence(timeout: 5))
      capture("\(theme)-\(tab)-\(largeText ? "AX5" : "default")", app: app)
      try audit(app, largeText: largeText)
    }
    app.openProfile()
    capture("\(theme)-Profile-\(largeText ? "AX5" : "default")", app: app)
    try audit(app, largeText: largeText)
    app.closeProfile()

    app.tab("Fuel").tap()
    app.buttons["openFoodLibrary"].tap()
    app.buttons["Restaurants"].tap()
    XCTAssertTrue(app.navigationBars["Restaurants"].waitForExistence(timeout: 10))
    capture("\(theme)-Restaurants", app: app)
    try audit(app, largeText: largeText)

    app.tab("Today").tap()
    app.buttons["quickLog"].tap()
    app.buttons["quickLog-food"].tap()
    let barcode = app.buttons["openBarcode"]
    XCTAssertTrue(barcode.waitForExistence(timeout: 10))
    for _ in 0..<5 where !barcode.isHittable { app.swipeUp() }
    barcode.tap()
    let scan = app.buttons["barcodeOpenCamera"]
    XCTAssertTrue(scan.waitForExistence(timeout: 10))
    for _ in 0..<5 where !scan.isHittable { app.swipeUp() }
    scan.tap()
    XCTAssertTrue(app.textFields["barcodeManualInput"].waitForExistence(timeout: 10))
    capture("\(theme)-Scanner", app: app)
    try audit(app, largeText: largeText)
  }

  /// The look book's workout board: a session in progress with ticked and open sets.
  @MainActor func testGraphiteWorkout() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--progress-ui-testing", "--theme-graphite", "--stack-fixture", "--showcase-fixture",
      "--showcase-workout",
    ]
    app.launch()
    XCTAssertTrue(app.tab("Train").waitForExistence(timeout: 20))
    app.tab("Train").tap()
    let resume = app.buttons["resumeWorkout"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    resume.tap()
    XCTAssertTrue(app.screenTitle("ActiveWorkout").waitForExistence(timeout: 5))
    capture("graphite-Workout-default", app: app)
    try audit(app, largeText: false)
  }

  /// The look book's scan result: the fictional fixture product found by its barcode.
  @MainActor func testGraphiteScanResult() throws {
    let app = launch(theme: "graphite", showcase: true)
    app.buttons["quickLog"].tap()
    app.buttons["quickLog-food"].tap()
    let barcode = app.buttons["openBarcode"]
    XCTAssertTrue(barcode.waitForExistence(timeout: 10))
    reveal(barcode, app: app)
    barcode.tap()
    let scan = app.buttons["barcodeOpenCamera"]
    XCTAssertTrue(scan.waitForExistence(timeout: 10))
    scan.tap()
    let input = app.textFields["barcodeManualInput"]
    XCTAssertTrue(input.waitForExistence(timeout: 10))
    input.tap()
    input.typeText("012345678905")
    app.buttons["barcodeConfirm"].tap()
    let lookup = app.buttons["barcodeLookup"]
    XCTAssertTrue(lookup.waitForExistence(timeout: 10))
    let permission = app.switches["barcodePermission"]
    reveal(permission, app: app)
    if permission.value as? String != "1" {
      permission.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }
    reveal(lookup, app: app)
    lookup.tap()
    let review = app.buttons["barcodeReview"]
    XCTAssertTrue(review.waitForExistence(timeout: 10))
    reveal(review, app: app)
    capture("graphite-ScanResult", app: app)
    try audit(app, largeText: false)
  }

  @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
    for _ in 0..<8 where !element.isHittable { app.swipeUp() }
    XCTAssertTrue(element.isHittable)
  }

  /// Verify the text reported by the normal-size lazy-list audit really grows.
  /// This compares fresh launches, independent of the system audit's resizing.
  @MainActor func testTextGrowthAcrossSizes() {
    var heights: [[CGFloat]] = []
    for largeText in [false, true] {
      let app = launch(theme: "graphite", largeText: largeText)
      app.tab("Progress").tap()
      let progress = app.staticTexts[
        "Keep daily photos, weigh-ins, and notes together. Add any combination that works for you."]
      reveal(progress, app: app)
      let progressHeight = progress.frame.height
      capture("growth-Progress-\(largeText ? "AX5" : "default")", app: app)
      app.openProfile()
      let profile = app.staticTexts[
        "These values stay on this device and are used only to make a starting estimate."]
      reveal(profile, app: app)
      let profileHeight = profile.frame.height
      capture("growth-Profile-\(largeText ? "AX5" : "default")", app: app)
      app.closeProfile()
      app.tab("Fuel").tap()
      app.buttons["openFoodLibrary"].tap()
      app.buttons["Restaurants"].tap()
      let restaurant = app.staticTexts[
        "Sample menus for now. These are not complete, verified restaurant menus."]
      reveal(restaurant, app: app)
      heights.append([progressHeight, profileHeight, restaurant.frame.height])
      capture("growth-Restaurants-\(largeText ? "AX5" : "default")", app: app)
      app.terminate()
    }
    for (index, name) in ["Progress", "Profile", "Restaurants"].enumerated() {
      XCTAssertGreaterThan(
        heights[1][index], heights[0][index] * 1.4,
        "\(name) text must grow at AX5: \(heights[0][index]) → \(heights[1][index])")
      print("TEXT GROWTH \(name): \(heights[0][index]) → \(heights[1][index])")
    }
  }

  /// Not a pass/fail check: prints how many clipped-text issues Today reports with and
  /// without the tab labels, to locate the issues the audit reports without an element.
  @MainActor func testClippedTextDiagnostic() {
    for iconsOnly in [false, true] {
      let app = XCUIApplication()
      app.launchArguments =
        ["--progress-ui-testing", "--theme-graphite", "--stack-fixture"]
        + (iconsOnly ? ["--tab-bar-icons-only"] : [])
      app.launch()
      XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
      var count = 0
      try? app.performAccessibilityAudit(for: [.textClipped]) { _ in
        count += 1
        return true
      }
      print("DIAGNOSTIC clipped iconsOnly=\(iconsOnly) count=\(count)")
      app.terminate()
    }
  }

  @MainActor func testGraphiteScreens() throws { try inspect(theme: "graphite") }
  @MainActor func testFrostScreens() throws { try inspect(theme: "frost") }
  @MainActor func testLargestTextScreens() throws {
    try inspect(theme: "graphite", largeText: true)
  }
}
