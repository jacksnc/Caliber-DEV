import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
@Suite("Derived food reuse index")
struct FoodReuseIndexTests {
  private let cutoff = Date(timeIntervalSinceReferenceDate: 1_000)

  @Test("Equivalent personal copies keep one stable, opaque key")
  func stableIdentity() {
    let original = rice()
    let copy = rice()
    #expect(original.id != copy.id)
    #expect(FoodReuseIndex.key(for: original) == FoodReuseIndex.key(for: copy))
    // Golden key also protects stored favorites from accidental format changes.
    #expect(
      FoodReuseIndex.key(for: original)
        == "personal:46b2bb208ee7afbac029be45b178b6eaf4363ddaaa7bd2d4ac9eb8181cfac089")
    copy.isSavedToLibrary = true
    #expect(FoodReuseIndex.key(for: original) == FoodReuseIndex.key(for: copy))
  }

  @Test("Preparation, portion, source and even tiny edited macro differences remain distinct")
  func distinctVersions() {
    let base = rice()
    let raw = rice()
    raw.name = "Rice, raw"
    let portion = rice()
    portion.servingDescription = "200 g"
    let source = rice()
    source.sourceType = .restaurantMenuItem
    let changedCalories = rice()
    changedCalories.calories = base.calories.nextUp
    let changedProtein = rice()
    changedProtein.proteinGrams = base.proteinGrams.nextUp
    let changedCarbs = rice()
    changedCarbs.carbGrams = base.carbGrams.nextUp
    let changedFat = rice()
    changedFat.fatGrams = base.fatGrams.nextUp
    let exactName = rice()
    exactName.name += " "
    let variants = [
      base, raw, portion, source, changedCalories, changedProtein, changedCarbs, changedFat,
      exactName,
    ]
    #expect(Set(variants.map { FoodReuseIndex.key(for: $0) }).count == variants.count)
    let a = rice()
    a.name = "ab"
    a.servingDescription = "c"
    let b = rice()
    b.name = "a"
    b.servingDescription = "bc"
    #expect(FoodReuseIndex.key(for: a) != FoodReuseIndex.key(for: b))
    let zero = rice()
    zero.carbGrams = 0
    let negativeZero = rice()
    negativeZero.carbGrams = -0.0
    #expect(FoodReuseIndex.key(for: zero) == FoodReuseIndex.key(for: negativeZero))
  }

  @Test("Different restaurant menu identities never merge otherwise identical foods")
  func menuIdentity() {
    let restaurant = Restaurant(name: "Fictional Restaurant")
    let menu = MenuItem(
      name: "Rice", baseCalories: 130, baseProtein: 2.69, baseCarbs: 28.17, baseFat: 0.28,
      category: .side)
    menu.restaurant = restaurant
    let a = rice()
    a.sourceType = .restaurantMenuItem
    a.menuItem = menu
    let b = rice()
    b.sourceType = .restaurantMenuItem
    b.menuItem = menu
    #expect(FoodReuseIndex.key(for: a) == FoodReuseIndex.key(for: b))
    let otherMenu = MenuItem(
      name: "Rice", baseCalories: 130, baseProtein: 2.69, baseCarbs: 28.17, baseFat: 0.28,
      category: .side)
    otherMenu.restaurant = restaurant
    b.menuItem = otherMenu
    #expect(FoodReuseIndex.key(for: a) != FoodReuseIndex.key(for: b))
    let prior = FoodReuseIndex.key(for: a)
    menu.name = "Renamed menu item"
    #expect(FoodReuseIndex.key(for: a) == prior)
  }

  @Test("Copies deduplicate, logged rows count once and the newest serving quantity wins")
  func dedupeAndLatestQuantity() throws {
    let first = DiaryEntry(
      date: cutoff.addingTimeInterval(-100), mealType: .lunch, foodItem: rice(), quantity: 3)
    let latest = DiaryEntry(date: cutoff, mealType: .dinner, foodItem: rice(), quantity: 0.5)
    let saved = rice()
    saved.isSavedToLibrary = true
    let result = FoodReuseIndex.build(
      entries: [first, latest, latest], savedFoods: [saved], through: cutoff)
    let food = try #require(result.first)
    #expect(result.count == 1)
    #expect(food.logCount == 2)
    #expect(food.quantity == 0.5)
    #expect(food.lastLoggedAt == cutoff)
    #expect(food.food === saved)
    #expect(first.quantity == 3 && latest.quantity == 0.5)
    #expect(saved.calories == 130 && saved.isSavedToLibrary)
    #expect(first.foodItem?.isSavedToLibrary == false)
  }

  @Test("Equal dates and duplicate saved foods resolve independently of fetch order")
  func deterministicTies() throws {
    let a = DiaryEntry(date: cutoff, mealType: .lunch, foodItem: rice(), quantity: 0.25)
    let b = DiaryEntry(date: cutoff, mealType: .dinner, foodItem: rice(), quantity: 2)
    a.id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    b.id = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
    let savedA = rice()
    savedA.isSavedToLibrary = true
    let savedB = rice()
    savedB.isSavedToLibrary = true
    savedA.id = UUID(uuidString: "00000000-0000-4000-8000-000000000011")!
    savedB.id = UUID(uuidString: "00000000-0000-4000-8000-000000000012")!
    for (entries, saved) in [([a, b], [savedB, savedA]), ([b, a], [savedA, savedB])] {
      let food = try #require(
        FoodReuseIndex.build(entries: entries, savedFoods: saved, through: cutoff).first)
      #expect(food.quantity == 0.25 && food.logCount == 2)
      #expect(food.food === savedA)
    }
  }

  @Test("The supplied cutoff is inclusive and never uses a different wall-clock date")
  func cutoffAndFuture() throws {
    let prior = DiaryEntry(
      date: cutoff.addingTimeInterval(-1), mealType: .lunch, foodItem: rice(), quantity: 2)
    let boundary = DiaryEntry(date: cutoff, mealType: .dinner, foodItem: rice(), quantity: 3)
    let future = DiaryEntry(
      date: cutoff.addingTimeInterval(0.001), mealType: .snack, foodItem: rice(), quantity: 4)
    let result = try #require(
      FoodReuseIndex.build(entries: [prior, boundary, future], savedFoods: [], through: cutoff)
        .first)
    #expect(result.logCount == 2 && result.quantity == 3 && result.lastLoggedAt == cutoff)
    #expect(FoodReuseIndex.build(entries: [future], savedFoods: [], through: cutoff).isEmpty)
    #expect(
      FoodReuseIndex.build(
        entries: [prior], savedFoods: [], through: Date(timeIntervalSinceReferenceDate: .nan)
      ).isEmpty)
  }

  @Test("Incomplete sources, invalid quantities, dates and overflowing totals are excluded")
  func invalidHistory() throws {
    let noName = rice()
    noName.name = "  "
    let noServing = rice()
    noServing.servingDescription = ""
    let negative = rice()
    negative.proteinGrams = -1
    let notFinite = rice()
    notFinite.calories = .nan
    let infinite = rice()
    infinite.carbGrams = .infinity
    let huge = rice()
    huge.calories = .greatestFiniteMagnitude
    var entries = [noName, noServing, negative, notFinite, infinite, huge].map {
      DiaryEntry(date: cutoff, mealType: .snack, foodItem: $0, quantity: 2)
    }
    entries += [0, -1, .nan, .infinity].map {
      DiaryEntry(date: cutoff, mealType: .snack, foodItem: rice(), quantity: $0)
    }
    let noFood = DiaryEntry(date: cutoff, mealType: .snack, foodItem: rice())
    noFood.foodItem = nil
    let badDate = DiaryEntry(
      date: Date(timeIntervalSinceReferenceDate: .infinity), mealType: .snack, foodItem: rice())
    entries += [noFood, badDate]
    let zero = rice()
    zero.calories = 0
    zero.proteinGrams = 0
    zero.carbGrams = 0
    zero.fatGrams = 0
    entries.append(DiaryEntry(date: cutoff, mealType: .snack, foodItem: zero))
    let result = FoodReuseIndex.build(
      entries: entries, savedFoods: [negative, noName], through: cutoff)
    #expect(result.count == 1)
    let valid = try #require(result.first)
    #expect(valid.food === zero)
  }

  @Test("Saved-only foods are reusable but do not appear in recent or frequent history")
  func savedWithoutHistory() throws {
    let saved = rice()
    saved.isSavedToLibrary = true
    let unflagged = rice()
    unflagged.name = "Not in My Foods"
    let future = DiaryEntry(date: cutoff.addingTimeInterval(1), mealType: .snack, foodItem: rice())
    let foods = FoodReuseIndex.build(
      entries: [future], savedFoods: [saved, unflagged], through: cutoff)
    let item = try #require(foods.first)
    #expect(foods.count == 1 && item.food === saved)
    #expect(item.logCount == 0 && item.lastLoggedAt == nil && item.quantity == 1)
    #expect(FoodReuseIndex.recent(foods).isEmpty)
    #expect(FoodReuseIndex.frequent(foods).isEmpty)
  }

  @Test("Recent and frequent rank by different evidence and enforce requested limits")
  func rankingAndLimits() throws {
    let a = rice()
    a.name = "A"
    let b = rice()
    b.name = "B"
    let c = rice()
    c.name = "C"
    let entries = [(a, [10, 30]), (b, [20, 21, 22]), (c, [25, 26])].flatMap { food, seconds in
      seconds.map {
        DiaryEntry(
          date: Date(timeIntervalSinceReferenceDate: Double($0)), mealType: .snack, foodItem: food)
      }
    }
    let foods = FoodReuseIndex.build(entries: entries, savedFoods: [], through: cutoff)
    #expect(FoodReuseIndex.recent(foods).map(\.food.name) == ["A", "C", "B"])
    #expect(FoodReuseIndex.frequent(foods).map(\.food.name) == ["B", "A", "C"])
    #expect(FoodReuseIndex.recent(foods, limit: 1).map(\.food.name) == ["A"])
    #expect(FoodReuseIndex.frequent(foods, limit: 2).map(\.food.name) == ["B", "A"])
    #expect(FoodReuseIndex.recent(foods, limit: 0).isEmpty)
    #expect(FoodReuseIndex.frequent(foods, limit: -1).isEmpty)
    #expect(FoodReuseIndex.recent(foods, limit: .max).count == 3)
    let reversed = FoodReuseIndex.build(
      entries: entries.reversed(), savedFoods: [], through: cutoff)
    #expect(foods.map(\.id) == reversed.map(\.id))
  }

  @Test("Equal frequency and recency use stable food IDs rather than fetch order")
  func rankingTies() {
    let a = rice()
    a.name = "A"
    let b = rice()
    b.name = "B"
    let entries = [a, b].map { DiaryEntry(date: cutoff, mealType: .snack, foodItem: $0) }
    let foods = FoodReuseIndex.build(entries: entries, savedFoods: [], through: cutoff)
    let expected = [FoodReuseIndex.key(for: a), FoodReuseIndex.key(for: b)].sorted()
    #expect(FoodReuseIndex.recent(foods.reversed()).map(\.id) == expected)
    #expect(FoodReuseIndex.frequent(foods.reversed()).map(\.id) == expected)
  }

  private func rice() -> FoodItem {
    FoodItem(
      name: "Rice, cooked", calories: 130, proteinGrams: 2.69, carbGrams: 28.17, fatGrams: 0.28,
      servingDescription: "100 g")
  }
}
