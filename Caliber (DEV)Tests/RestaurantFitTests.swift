import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
@Suite("Restaurant fit ranking")
struct RestaurantFitTests {
  private func item(_ name: String, _ kcal: Double, protein: Double) -> MenuItem {
    MenuItem(
      name: name, baseCalories: kcal, baseProtein: protein, baseCarbs: 0, baseFat: 0,
      category: .entree)
  }

  @Test func windowCentresOnWhatIsLeftToday() throws {
    var eaten = MacroTotals()
    eaten.calories = 1462
    eaten.protein = 142
    let window = try #require(RestaurantFit.window(goal: 2350, proteinGoal: 180, eaten: eaten))
    #expect(window.minCalories == 799)
    #expect(window.maxCalories == 977)
    #expect(window.minProtein == 15)
  }

  @Test func noGoalOrNothingLeftMeansNoWindow() {
    var eaten = MacroTotals()
    eaten.calories = 2300
    #expect(RestaurantFit.window(goal: nil, proteinGoal: nil, eaten: MacroTotals()) == nil)
    #expect(RestaurantFit.window(goal: 0, proteinGoal: 100, eaten: MacroTotals()) == nil)
    #expect(RestaurantFit.window(goal: 2350, proteinGoal: 180, eaten: eaten) == nil)
  }

  @Test func fitsComeFirstThenCloseAndMissesAreLeftOut() {
    let window = RestaurantFit.Window(minCalories: 585, maxCalories: 715, minProtein: 35)
    let matches = RestaurantFit.matches(
      in: [
        item("Too big", 1200, protein: 60), item("Close", 570, protein: 39),
        item("Fits far", 600, protein: 36), item("Fits near", 650, protein: 38),
        item("Low protein", 650, protein: 10), item("Unlisted", 0, protein: 0),
      ], window: window)
    #expect(matches.map(\.item.name) == ["Fits near", "Fits far", "Close"])
    #expect(matches.map(\.verdict) == [.fits, .fits, .close])
  }
}
