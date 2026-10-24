import Foundation

/// A temporary value snapshot. Changing a source food later cannot change a
/// saved recipe, and canceling the editor writes nothing to the food library.
struct RecipeIngredientDraft: Identifiable {
  var id = UUID()
  var name: String
  var servingDescription: String
  var totals: MacroTotals
  var quantity: Double = 1
  var sourceType: FoodSourceType = .generic
}
