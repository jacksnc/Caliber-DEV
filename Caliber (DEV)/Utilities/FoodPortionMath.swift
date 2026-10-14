import Foundation

nonisolated enum FoodPortionUnit: String, CaseIterable, Identifiable {
  case grams, ounces, portions
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .grams: "g"
    case .ounces: "oz"
    case .portions: "Portions"
    }
  }
}

nonisolated struct ResolvedFoodPortion: Equatable {
  let grams: Double?
  let quantity: Double
}

/// Weight ounces, never fluid ounces. Household measures need source-provided
/// mass/density and are deliberately unavailable when those facts are missing.
nonisolated enum FoodPortionMath {
  static let gramsPerOunce = 28.349523125

  static func resolve(value: Double, unit: FoodPortionUnit, basisGrams: Double?) throws
    -> ResolvedFoodPortion
  {
    guard value.isFinite, value > 0 else { throw FoodCatalogError.invalidPortion }
    guard let basisGrams else {
      guard unit == .portions else { throw FoodCatalogError.invalidPortion }
      return ResolvedFoodPortion(grams: nil, quantity: value)
    }
    guard basisGrams.isFinite, basisGrams > 0 else { throw FoodCatalogError.invalidPortion }
    let grams: Double
    switch unit {
    case .grams: grams = value
    case .ounces: grams = value * gramsPerOunce
    case .portions: grams = value * basisGrams
    }
    guard grams.isFinite, grams > 0 else { throw FoodCatalogError.invalidPortion }
    return ResolvedFoodPortion(grams: grams, quantity: 1)
  }

  static func amount(grams: Double, unit: FoodPortionUnit, basisGrams: Double) throws -> Double {
    guard grams.isFinite, grams > 0, basisGrams.isFinite, basisGrams > 0 else {
      throw FoodCatalogError.invalidPortion
    }
    let amount: Double
    switch unit {
    case .grams: amount = grams
    case .ounces: amount = grams / gramsPerOunce
    case .portions: amount = grams / basisGrams
    }
    guard amount.isFinite, amount > 0 else { throw FoodCatalogError.invalidPortion }
    return amount
  }
}
