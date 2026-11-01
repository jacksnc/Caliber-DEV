import FoodCore
import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor @Test func oikosSearchAndBarcodeUseTheSameReviewedServing() async throws {
  let loaded = await BundledBarcodeService.prepared()
  let service = try #require(loaded.service)
  let results = try await service.searchFoods(query: "oikos pro")
  let food = try #require(results.first { $0.id == "label:oikos-pro-vanilla-cup-us" })
  #expect(food.totals == MacroTotals(calories: 130, protein: 20, carbs: 6, fat: 3))
  #expect(food.basisGrams == 150)
  for code in ["036632042552", "0036632042552", "00036632042552"] {
    let product = try await service.lookupFood(barcode: code)
    #expect(product.calories == food.totals.calories)
    #expect(product.proteinGrams == 20 && product.carbGrams == 6 && product.basisGrams == 150)
  }
  #expect(results.filter { $0.id == "barcode:00036632042552" }.isEmpty)
  #expect(try food.portionTotals(grams: 300).calories == 260)
}

@MainActor @Test func labelResourceRejectsUnreviewedDuplicateAndIncompleteData() throws {
  let url = try #require(Bundle.main.url(forResource: "LabelFoods", withExtension: "json"))
  let original = try #require(
    try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
  for change in 0..<5 {
    var doc = original
    var foods = try #require(doc["foods"] as? [[String: Any]])
    switch change {
    case 0: doc["reviewed"] = false
    case 1: foods.append(foods[0])
    case 2: foods[0].removeValue(forKey: "proteinGrams")
    case 3: foods[0]["gtin14"] = "00000000000000"
    default: foods[0]["servingMilliliters"] = 150
    }
    doc["foods"] = foods
    let bytes = try JSONSerialization.data(withJSONObject: doc)
    #expect(throws: (any Error).self) { try LabelFoodCatalog.decode(bytes) }
  }
}

@MainActor @Test func cameraUPCEExpandsWithoutConfusingEAN8() throws {
  #expect(BarcodeScanValue.normalize("04252614", symbology: .upcE) == "042100005264")
  #expect(BarcodeScanValue.normalize("04252614", symbology: .ean8) == nil)
  #expect(BarcodeScanValue.normalize("0036632042552", symbology: .ean13) == "036632042552")
  #expect(BarcodeScanValue.normalize("04252615", symbology: .upcE) == nil)
  for length in [8, 12, 13, 14] {
    #expect(throws: BarcodeValue.ValidationError.invalidProductCode) {
      try BarcodeValue.normalize(String(repeating: "0", count: length))
    }
  }
}
