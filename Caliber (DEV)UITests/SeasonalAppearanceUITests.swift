import UIKit
import XCTest

final class SeasonalAppearanceUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  @MainActor private func launch(date: String, graphite: Bool = false, reduceMotion: Bool = false)
    -> XCUIApplication
  {
    let app = XCUIApplication()
    app.launchArguments = [
      "--progress-ui-testing", "--showcase-fixture",
      graphite ? "--theme-graphite" : "--theme-frost",
      "--season-now", date, "--season-zone", "America/New_York",
    ]
    if reduceMotion { app.launchArguments += ["--season-reduce-motion"] }
    app.launch()
    XCTAssertTrue(app.tab("Today").waitForExistence(timeout: 20))
    return app
  }

  @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<14 where !element.isHittable {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
    }
    XCTAssertTrue(element.isHittable)
  }

  /// Only sample side-background strips, excluding clocks, text, controls and the tab bar.
  /// This checks the requested effect rather than changes elsewhere in the screenshot.
  @MainActor private func backgroundSample(_ screenshot: XCUIScreenshot) throws -> Data {
    let image = try XCTUnwrap(screenshot.image.cgImage)
    let height = max(1, image.height - 480)
    let left = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 240, width: 40, height: height)))
    let right = try XCTUnwrap(
      image.cropping(to: CGRect(x: image.width - 40, y: 240, width: 40, height: height)))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let sample = UIGraphicsImageRenderer(size: CGSize(width: 80, height: height), format: format)
      .image { context in
        context.cgContext.draw(left, in: CGRect(x: 0, y: 0, width: 40, height: height))
        context.cgContext.draw(right, in: CGRect(x: 40, y: 0, width: 40, height: height))
      }
    return try XCTUnwrap(sample.pngData())
  }

  @MainActor private func capture(_ name: String, app: XCUIApplication) {
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = name
    image.lifetime = .keepAlways
    add(image)
  }

  @MainActor func testChristmasCannotBeSelectedBeforeLocalDecemberAndEndsInJanuary() {
    for date in ["2026-12-01T04:59:59Z", "2027-01-01T05:00:00Z"] {
      let app = launch(date: date)
      XCTAssertFalse(app.descendants(matching: .any)["christmasAppearanceBadge"].exists)
      app.openSettings()
      let status = app.descendants(matching: .any)["seasonalAppearanceStatus"].firstMatch
      reveal(status, in: app)
      XCTAssertTrue(status.label.contains("begins December 1"), status.label)
      XCTAssertFalse(app.switches["seasonalSnowMotion"].exists)
      XCTAssertFalse(app.buttons["Christmas"].exists)
      app.terminate()
    }
  }

  @MainActor func testDecemberSnowKeepsDiaryActionsAndHasAnAccessibleMotionChoice() throws {
    let app = launch(date: "2026-12-01T05:00:00Z", graphite: true)
    XCTAssertTrue(app.descendants(matching: .any)["christmasAppearanceBadge"].exists)
    let snowBefore = try backgroundSample(app.screenshot())
    Thread.sleep(forTimeInterval: 2)
    XCTAssertNotEqual(
      try backgroundSample(app.screenshot()), snowBefore, "Live snow must change the background")
    capture("Christmas Graphite Today with falling snow", app: app)
    app.buttons["todayFuel-page-protein"].tap()
    XCTAssertTrue(app.buttons["todayFuel-page-protein"].isSelected)
    app.openSettings()
    let motion = app.switches["seasonalSnowMotion"]
    reveal(motion, in: app)
    XCTAssertEqual(motion.value as? String, "1")
    capture("Christmas Graphite automatic appearance and logo", app: app)
    motion.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    XCTAssertEqual(motion.value as? String, "0")
    app.leaveProfile()
    app.tab("Fuel").tap()
    reveal(app.buttons["diaryAddFood"], in: app)
    app.buttons["diaryAddFood"].tap()
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
  }

  @MainActor func testFrostChristmasWithReduceMotionStillHasUsableNavigation() throws {
    let app = launch(date: "2026-12-15T12:00:00Z", reduceMotion: true)
    XCTAssertTrue(app.descendants(matching: .any)["christmasAppearanceBadge"].exists)
    let snowBefore = try backgroundSample(app.screenshot())
    Thread.sleep(forTimeInterval: 2)
    XCTAssertEqual(
      try backgroundSample(app.screenshot()), snowBefore, "Reduced-motion snow must remain still")
    capture("Christmas Frost Reduce Motion static snow", app: app)
    app.openSettings()
    let status = app.descendants(matching: .any)["seasonalAppearanceStatus"].firstMatch
    reveal(status, in: app)
    XCTAssertTrue(status.label.contains("is active"))
    reveal(app.switches["seasonalSnowMotion"], in: app)
    capture("Christmas Frost seasonal logo", app: app)
    app.leaveProfile()
    app.tab("Progress").tap()
    XCTAssertTrue(app.buttons["addProgressEntry"].waitForExistence(timeout: 10))
  }
}
