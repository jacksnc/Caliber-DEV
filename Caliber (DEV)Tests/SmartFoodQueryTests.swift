import Testing

@testable import Caliber__DEV_

@Suite("Smart food search")
struct SmartFoodQueryTests {
  @Test func listSplitsIntoFoodsWithAmounts() {
    let phrases = SmartFoodQuery.phrases(in: "2 eggs, a slice of toast and a banana")
    #expect(phrases.map(\.terms) == ["egg", "toast", "banana"])
    #expect(phrases.map(\.quantity) == [2, 1, 1])
    #expect(phrases.map(\.unit) == [nil, "slice", nil])
    #expect(SmartFoodQuery.isList(phrases))
  }

  @Test func namesWithAndStayTogether() {
    let phrases = SmartFoodQuery.phrases(in: "mac and cheese")
    #expect(phrases.map(\.terms) == ["mac and cheese"])
    #expect(!SmartFoodQuery.isList(phrases))
  }

  @Test func fractionsAndGrams() {
    let phrases = SmartFoodQuery.phrases(in: "1 1/2 cups rice + 150 g chicken breast")
    #expect(phrases.map(\.quantity) == [1.5, 150])
    #expect(phrases.map(\.unit) == ["cup", "g"])
    #expect(phrases.map(\.terms) == ["rice", "chicken breast"])
  }

  @Test func portionUsesOnlyListedServings() {
    let toast = FoodPhrase(quantity: 2, unit: "slice", terms: "toast", text: "2 slices toast")
    let servings = [(id: "s1", label: "1 slice"), (id: "s2", label: "1 cup, cubes")]
    let slice = SmartFoodQuery.portion(for: toast, servings: servings)
    #expect(slice?.choiceID == "s1")
    #expect(slice?.amount == 2)

    let grams = FoodPhrase(quantity: 150, unit: "g", terms: "chicken", text: "150 g chicken")
    let weight = SmartFoodQuery.portion(for: grams, servings: [])
    #expect(weight?.choiceID == "grams")
    #expect(weight?.amount == 150)

    // No unit and two listed servings: the person chooses; nothing is guessed.
    let eggs = FoodPhrase(quantity: 2, unit: nil, terms: "egg", text: "2 eggs")
    let eggServings = [(id: "l", label: "1 large"), (id: "m", label: "1 medium")]
    #expect(SmartFoodQuery.portion(for: eggs, servings: eggServings)?.choiceID == nil)
    #expect(SmartFoodQuery.portion(for: eggs, servings: [eggServings[0]])?.choiceID == "l")
  }

  @Test func oneTypoStillMatches() {
    #expect(FoodSearchText.fuzzyMatches("Chicken breast, grilled", query: "chiken brest"))
    #expect(!FoodSearchText.fuzzyMatches("Chicken breast", query: "salmon"))
  }
}
