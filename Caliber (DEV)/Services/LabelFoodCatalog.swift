import Foundation

/// Reviewed per-serving label records. A manufacturer correction can supersede a
/// stale public barcode record without rewriting anyone's previously logged food.
struct LabelFoodCatalog: Decodable {
  let schemaVersion: Int
  let reviewed: Bool
  let foods: [LabelFood]

  static let empty = LabelFoodCatalog(schemaVersion: 1, reviewed: true, foods: [])

  static func load(bundle: Bundle = .main) throws -> Self {
    guard let url = bundle.url(forResource: "LabelFoods", withExtension: "json") else {
      throw FoodCatalogError.unavailable
    }
    return try decode(Data(contentsOf: url))
  }

  static func decode(_ data: Data) throws -> Self {
    guard data.count <= 5_000_000 else { throw FoodCatalogError.invalidData }
    let result = try JSONDecoder().decode(Self.self, from: data)
    guard result.schemaVersion == 1, result.reviewed, result.foods.count <= 1_000,
      result.foods.allSatisfy(\.isValid),
      Set(result.foods.map(\.id)).count == result.foods.count
    else { throw FoodCatalogError.invalidData }
    let codes = result.foods.compactMap(\.gtin14)
    guard Set(codes).count == codes.count else { throw FoodCatalogError.invalidData }
    return result
  }
}

struct LabelFood: Decodable, Identifiable {
  let id: String
  let brand: String
  let name: String
  let aliases: String
  let country: String
  let gtin14: String?
  let servingDescription: String
  let servingGrams: Double?
  let servingMilliliters: Double?
  let calories: Double
  let proteinGrams: Double
  let carbGrams: Double
  let fatGrams: Double
  let sourceURL: String
  let sourceLocator: String
  let retrievedOn: String
  let barcodeSourceURL: String?

  var isValid: Bool {
    let text = [id, brand, name, servingDescription, sourceLocator]
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    let validDate =
      formatter.date(from: retrievedOn).map { formatter.string(from: $0) == retrievedOn } ?? false
    return text.allSatisfy {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 500
    }
      && aliases.count <= 500 && country == "US" && validDate
      && Self.validURL(sourceURL)
      && (gtin14.map {
        $0.count == 14 && (try? BarcodeValue.gtin14($0)) == $0 && $0.contains(where: { $0 != "0" })
      } ?? true)
      && (gtin14 == nil || barcodeSourceURL.map(Self.validURL) == true)
      && !(servingGrams != nil && servingMilliliters != nil)
      && [servingGrams, servingMilliliters].compactMap { $0 }.allSatisfy {
        $0.isFinite && $0 > 0 && $0 <= 10_000
      }
      && [calories, proteinGrams, carbGrams, fatGrams].allSatisfy {
        $0.isFinite && $0 >= 0 && $0 <= 10_000
      }
  }

  nonisolated private static func validURL(_ value: String) -> Bool {
    guard let url = URL(string: value), url.scheme == "https", let host = url.host,
      host.contains("."), url.user == nil, url.password == nil,
      !value.contains(where: \.isWhitespace)
    else { return false }
    return true
  }

  var reference: FoodNutritionReference {
    FoodNutritionReference(
      id: "label:" + id, name: brand + " · " + name,
      totals: MacroTotals(
        calories: calories, protein: proteinGrams, carbs: carbGrams, fat: fatGrams),
      basisDescription: servingDescription, basisGrams: servingGrams,
      sourceLabel: "Package label · " + retrievedOn + (gtin14.map { " · GTIN " + $0 } ?? ""),
      sourceURL: URL(string: sourceURL)!, attribution: "Label facts · " + sourceLocator,
      sourceNote:
        "Nutrition is for the stated serving. Compare the flavor, size and current package before logging. Personal edits never change the source record."
    )
  }

  func barcodeProduct(requested: String) -> BarcodeNutritionProduct {
    BarcodeNutritionProduct(
      barcode: requested, name: name, brand: brand, calories: calories,
      proteinGrams: proteinGrams, carbGrams: carbGrams, fatGrams: fatGrams,
      basisDescription: servingDescription, basisGrams: servingGrams,
      sourceURL: URL(string: sourceURL)!, sourceName: "Reviewed package label",
      attribution: sourceLocator + " · " + retrievedOn,
      sourceNote: reference.sourceNote, sourceRecordID: id)
  }
}
