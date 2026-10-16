import Foundation
import Testing

@testable import CaliberDatabase

private let menuInputHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

/// Authored fictional fixtures only. These values do not describe any real restaurant,
/// permission grant or nutrition claim. No fixture is shipped or downloaded by this reader.
private func menuFixture() -> [String: Any] {
  [
    "schemaVersion": 1, "fictional": true, "inputSHA256": menuInputHash,
    "sources": [
      [
        "id": "fictional-source", "name": "Fictional authored test source",
        "url": "https://menus.example.invalid/fictional", "retrievedOn": "2024-02-29",
        "license": [
          "status": "fixture",
          "permissionReference": "Fictional authored unit-test data; no real approval asserted",
          "attribution": "Fictional unit-test authors",
        ],
      ]
    ],
    "restaurants": [
      [
        "id": "fictional-cafe", "name": "Fictional Café", "sourceID": "fictional-source",
        "items": [
          [
            "id": "fictional-entree", "name": "Fictional entree", "category": "entree",
            "servingDescription": "1 fictional entree", "servingGrams": 287.125,
            "calories": 501.75, "proteinGrams": 34.125, "carbGrams": 50.25, "fatGrams": 16.375,
          ],
          [
            "id": "fictional-drink", "name": "Fictional drink", "category": "drink",
            "servingDescription": "1 fictional cup; mass unknown", "servingGrams": NSNull(),
            "calories": 0.0, "proteinGrams": 0.0, "carbGrams": 0.0, "fatGrams": 0.0,
          ],
        ],
      ]
    ],
  ]
}

private func menuData(_ object: [String: Any]) throws -> Data {
  try JSONSerialization.data(
    withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
}

private func menuChangeSource(
  _ object: inout [String: Any], _ change: (inout [String: Any]) -> Void
) {
  var sources = object["sources"] as! [[String: Any]]
  change(&sources[0])
  object["sources"] = sources
}

private func menuChangeLicense(
  _ object: inout [String: Any], _ change: (inout [String: Any]) -> Void
) {
  menuChangeSource(&object) { source in
    var license = source["license"] as! [String: Any]
    change(&license)
    source["license"] = license
  }
}

private func menuChangeRestaurant(
  _ object: inout [String: Any], _ change: (inout [String: Any]) -> Void
) {
  var restaurants = object["restaurants"] as! [[String: Any]]
  change(&restaurants[0])
  object["restaurants"] = restaurants
}

private func menuChangeItem(_ object: inout [String: Any], _ change: (inout [String: Any]) -> Void)
{
  menuChangeRestaurant(&object) { restaurant in
    var items = restaurant["items"] as! [[String: Any]]
    change(&items[0])
    restaurant["items"] = items
  }
}

@Test func restaurantMenuEmptyProductionRegistryRequiresNoFabricatedLicense() throws {
  let data = try menuData([
    "schemaVersion": 1, "fictional": false, "inputSHA256": menuInputHash,
    "sources": [], "restaurants": [],
  ])
  let catalog = try RestaurantMenuCatalog(data: data)
  #expect(!catalog.fictional)
  #expect(catalog.schemaVersion == 1)
  #expect(catalog.inputSHA256 == menuInputHash)
  #expect(catalog.sources.isEmpty)
  #expect(catalog.restaurants.isEmpty)
  #expect(catalog.restaurant(id: "missing") == nil)
}

@Test func restaurantMenuFictionalDataRequiresExplicitOptInAndRetainsEverySourceValue() throws {
  let data = try menuData(menuFixture())
  #expect(throws: RestaurantMenuCatalogError.fictionalNotAllowed) {
    try RestaurantMenuCatalog(data: data)
  }
  let catalog = try RestaurantMenuCatalog(data: data, allowFictional: true)
  #expect(catalog.fictional)
  let source = try #require(catalog.sources.first)
  #expect(source.id == "fictional-source")
  #expect(source.name == "Fictional authored test source")
  #expect(source.url == "https://menus.example.invalid/fictional")
  #expect(source.retrievedOn == "2024-02-29")
  #expect(source.license.status == "fixture")
  #expect(source.license.permissionReference.contains("no real approval asserted"))
  #expect(source.license.attribution == "Fictional unit-test authors")
  let restaurant = try #require(catalog.restaurant(id: "fictional-cafe"))
  #expect(restaurant.sourceID == source.id)
  #expect(restaurant.items.count == 2)
  let entree = restaurant.items[0]
  #expect(entree.id == "fictional-entree")
  #expect(entree.name == "Fictional entree")
  #expect(entree.category == "entree")
  #expect(entree.servingDescription == "1 fictional entree")
  #expect(entree.servingGrams == 287.125)
  #expect(entree.calories == 501.75)
  #expect(entree.proteinGrams == 34.125)
  #expect(entree.carbGrams == 50.25)
  #expect(entree.fatGrams == 16.375)
  #expect(restaurant.items[1].servingGrams == nil)
  #expect(restaurant.items[1].calories == 0)
}

@Test func restaurantMenuNameLookupFoldsAccentsCaseAndWidthWithoutChangingIdentity() throws {
  let catalog = try RestaurantMenuCatalog(data: menuData(menuFixture()), allowFictional: true)
  #expect(catalog.restaurants(named: "  ＦＩＣＴＩＯＮＡＬ　ＣＡＦＥ  ").map(\.id) == ["fictional-cafe"])
  #expect(catalog.restaurants(named: "fictional café").map(\.id) == ["fictional-cafe"])
  #expect(catalog.restaurants(named: "Fictional").isEmpty)
  #expect(catalog.restaurants(named: "").isEmpty)
  #expect(catalog.restaurant(id: "FICTIONAL-CAFE") == nil)
}

@Test func restaurantMenuPermissionIsAnOpaqueDeclarationRatherThanAnAutomaticLegalApproval() throws
{
  var object = menuFixture()
  object["fictional"] = false
  menuChangeSource(&object) { $0["url"] = "https://127.0.0.1/fictional-parser-test" }
  menuChangeLicense(&object) { $0["status"] = "approved" }
  let catalog = try RestaurantMenuCatalog(data: menuData(object))
  #expect(!catalog.fictional)
  #expect(catalog.sources[0].license.status == "approved")
  #expect(
    catalog.sources[0].license.permissionReference
      == "Fictional authored unit-test data; no real approval asserted")
}

@Test func restaurantMenuAllowsUnusedSourcesAndEmptyItemArrays() throws {
  var object = menuFixture()
  object["restaurants"] = []
  let unused = try RestaurantMenuCatalog(data: menuData(object), allowFictional: true)
  #expect(unused.sources.count == 1)
  #expect(unused.restaurants.isEmpty)
  object = menuFixture()
  menuChangeRestaurant(&object) { $0["items"] = [] }
  let emptyItems = try RestaurantMenuCatalog(data: menuData(object), allowFictional: true)
  #expect(emptyItems.restaurants[0].items.isEmpty)
}

@Test(arguments: [
  "schema", "schemaBool", "fictionalType", "digestUppercase", "digestShort", "sourceID",
  "sourceIDLong", "duplicateSource", "sourceName", "dateInvalid", "dateTime", "dateZeroYear",
  "permissionEmpty", "permissionLong", "attributionEmpty", "licenseStatus", "unknownTop",
  "unknownSource", "unknownLicense", "unknownRestaurant", "unknownItem", "missingGrams",
  "missingSourceField", "restaurantID", "duplicateRestaurant", "restaurantNameLong",
  "danglingSource", "duplicateItem", "duplicateItemAcrossRestaurants", "category", "itemNameEmpty",
  "itemNameLong", "descriptionLong", "descriptionControl", "negativeCalories", "oversizedMacro",
  "macroBool", "macroNull", "macroString", "zeroGrams", "negativeGrams", "oversizedGrams",
  "gramsBool", "gramsString",
])
func restaurantMenuRejectsUnknownMissingMalformedAndDuplicateData(_ scenario: String) throws {
  var object = menuFixture()
  switch scenario {
  case "schema": object["schemaVersion"] = 2
  case "schemaBool": object["schemaVersion"] = true
  case "fictionalType": object["fictional"] = 1
  case "digestUppercase": object["inputSHA256"] = menuInputHash.uppercased()
  case "digestShort": object["inputSHA256"] = "abc"
  case "sourceID": menuChangeSource(&object) { $0["id"] = "Uppercase" }
  case "sourceIDLong": menuChangeSource(&object) { $0["id"] = String(repeating: "a", count: 97) }
  case "duplicateSource":
    let sources = object["sources"] as! [[String: Any]]
    object["sources"] = sources + sources
  case "sourceName": menuChangeSource(&object) { $0["name"] = " " }
  case "dateInvalid": menuChangeSource(&object) { $0["retrievedOn"] = "2026-02-29" }
  case "dateTime": menuChangeSource(&object) { $0["retrievedOn"] = "2026-10-15T00:00:00Z" }
  case "dateZeroYear": menuChangeSource(&object) { $0["retrievedOn"] = "0000-01-01" }
  case "permissionEmpty": menuChangeLicense(&object) { $0["permissionReference"] = "" }
  case "permissionLong":
    menuChangeLicense(&object) { $0["permissionReference"] = String(repeating: "a", count: 1_001) }
  case "attributionEmpty": menuChangeLicense(&object) { $0["attribution"] = "\n" }
  case "licenseStatus": menuChangeLicense(&object) { $0["status"] = "approved" }
  case "unknownTop": object["unexpected"] = "value"
  case "unknownSource": menuChangeSource(&object) { $0["unexpected"] = "value" }
  case "unknownLicense": menuChangeLicense(&object) { $0["unexpected"] = "value" }
  case "unknownRestaurant": menuChangeRestaurant(&object) { $0["unexpected"] = "value" }
  case "unknownItem": menuChangeItem(&object) { $0["unexpected"] = "value" }
  case "missingGrams": menuChangeItem(&object) { $0.removeValue(forKey: "servingGrams") }
  case "missingSourceField": menuChangeSource(&object) { $0.removeValue(forKey: "url") }
  case "restaurantID": menuChangeRestaurant(&object) { $0["id"] = "invalid space" }
  case "duplicateRestaurant":
    let restaurants = object["restaurants"] as! [[String: Any]]
    object["restaurants"] = restaurants + restaurants
  case "restaurantNameLong":
    menuChangeRestaurant(&object) { $0["name"] = String(repeating: "a", count: 201) }
  case "danglingSource": menuChangeRestaurant(&object) { $0["sourceID"] = "missing" }
  case "duplicateItem":
    menuChangeRestaurant(&object) { restaurant in
      let items = restaurant["items"] as! [[String: Any]]
      restaurant["items"] = items + [items[0]]
    }
  case "duplicateItemAcrossRestaurants":
    var restaurants = object["restaurants"] as! [[String: Any]]
    var duplicate = restaurants[0]
    duplicate["id"] = "second-fictional-cafe"
    restaurants.append(duplicate)
    object["restaurants"] = restaurants
  case "category": menuChangeItem(&object) { $0["category"] = "other" }
  case "itemNameEmpty": menuChangeItem(&object) { $0["name"] = "" }
  case "itemNameLong": menuChangeItem(&object) { $0["name"] = String(repeating: "a", count: 201) }
  case "descriptionLong":
    menuChangeItem(&object) { $0["servingDescription"] = String(repeating: "a", count: 301) }
  case "descriptionControl":
    menuChangeItem(&object) { $0["servingDescription"] = "Serving\ncontrol" }
  case "negativeCalories": menuChangeItem(&object) { $0["calories"] = -0.001 }
  case "oversizedMacro": menuChangeItem(&object) { $0["proteinGrams"] = 1_000_000.1 }
  case "macroBool": menuChangeItem(&object) { $0["calories"] = true }
  case "macroNull": menuChangeItem(&object) { $0["fatGrams"] = NSNull() }
  case "macroString": menuChangeItem(&object) { $0["carbGrams"] = "50.25" }
  case "zeroGrams": menuChangeItem(&object) { $0["servingGrams"] = 0 }
  case "negativeGrams": menuChangeItem(&object) { $0["servingGrams"] = -1 }
  case "oversizedGrams": menuChangeItem(&object) { $0["servingGrams"] = 1_000_000.1 }
  case "gramsBool": menuChangeItem(&object) { $0["servingGrams"] = true }
  case "gramsString": menuChangeItem(&object) { $0["servingGrams"] = "287.125" }
  default: Issue.record("Unrecognized test mutation")
  }
  #expect(throws: RestaurantMenuCatalogError.invalidData) {
    try RestaurantMenuCatalog(data: menuData(object), allowFictional: true)
  }
}

@Test(arguments: [
  "http://menus.example.invalid/", "HTTPS://menus.example.invalid/", "https:///missing",
  "https://user:password@menus.example.invalid/", "https://menus.example.invalid/with space",
  "https://menus.example.invalid\\bad", "https://menus.example.invalid/\ncontrol",
])
func restaurantMenuRejectsUnsafeSourceURLs(_ url: String) throws {
  var object = menuFixture()
  menuChangeSource(&object) { $0["url"] = url }
  #expect(throws: RestaurantMenuCatalogError.invalidData) {
    try RestaurantMenuCatalog(data: menuData(object), allowFictional: true)
  }
}

@Test(arguments: [
  "https://example.com/menu", "https://example.org/menu", "https://example.net/menu",
  "https://example.com./menu", "https://menus.example.invalid/", "https://menus.test/",
  "https://menus.example/",
])
func restaurantMenuProductionRejectsExampleHostsEvenWithApprovedDeclaration(_ url: String) throws {
  var object = menuFixture()
  object["fictional"] = false
  menuChangeSource(&object) { $0["url"] = url }
  menuChangeLicense(&object) { $0["status"] = "approved" }
  #expect(throws: RestaurantMenuCatalogError.invalidData) {
    try RestaurantMenuCatalog(data: menuData(object))
  }
}

@Test func restaurantMenuRejectsDuplicateJSONKeysIncludingEscapesAtEveryObjectLevel() throws {
  let original = String(decoding: try menuData(menuFixture()), as: UTF8.self)
  let cases = [
    original.replacingOccurrences(
      of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"schemaVersion\":1"),
    original.replacingOccurrences(
      of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"\\u0073chemaVersion\":1"),
    original.replacingOccurrences(
      of: "\"id\":\"fictional-source\"",
      with: "\"id\":\"fictional-source\",\"id\":\"fictional-source\""),
    original.replacingOccurrences(
      of: "\"status\":\"fixture\"", with: "\"status\":\"fixture\",\"status\":\"fixture\""),
    original.replacingOccurrences(
      of: "\"id\":\"fictional-cafe\"", with: "\"id\":\"fictional-cafe\",\"id\":\"fictional-cafe\""),
    original.replacingOccurrences(
      of: "\"id\":\"fictional-entree\"",
      with: "\"id\":\"fictional-entree\",\"id\":\"fictional-entree\""),
  ]
  for candidate in cases {
    #expect(candidate != original)
    #expect(throws: RestaurantMenuCatalogError.invalidData) {
      try RestaurantMenuCatalog(data: Data(candidate.utf8), allowFictional: true)
    }
  }
}

@Test func restaurantMenuRejectsOversizedCountsDataDeepNestingAndMalformedJSON() throws {
  for data in [
    Data(), Data([0xFF]), Data("{}{}".utf8), Data("{\"a\":".utf8),
    Data((String(repeating: "[", count: 25) + "0" + String(repeating: "]", count: 25)).utf8),
    Data(repeating: 32, count: 5_000_001),
  ] {
    #expect(throws: RestaurantMenuCatalogError.invalidData) {
      try RestaurantMenuCatalog(data: data, allowFictional: true)
    }
  }
  var sourceCount = menuFixture()
  let source = (sourceCount["sources"] as! [[String: Any]])[0]
  sourceCount["sources"] = Array(repeating: source, count: 101)
  var restaurantCount = menuFixture()
  let restaurant = (restaurantCount["restaurants"] as! [[String: Any]])[0]
  restaurantCount["restaurants"] = Array(repeating: restaurant, count: 101)
  var itemCount = menuFixture()
  let item = (restaurant["items"] as! [[String: Any]])[0]
  menuChangeRestaurant(&itemCount) { $0["items"] = Array(repeating: item, count: 1_001) }
  var totalCount = menuFixture()
  var thousand = restaurant
  thousand["items"] = Array(repeating: item, count: 1_000)
  totalCount["restaurants"] = Array(repeating: thousand, count: 11)
  for object in [sourceCount, restaurantCount, itemCount, totalCount] {
    #expect(throws: RestaurantMenuCatalogError.invalidData) {
      try RestaurantMenuCatalog(data: menuData(object), allowFictional: true)
    }
  }
  let valid = String(decoding: try menuData(menuFixture()), as: UTF8.self)
  let nonfinite = valid.replacingOccurrences(of: "501.75", with: "1e999")
  #expect(nonfinite != valid)
  #expect(throws: RestaurantMenuCatalogError.invalidData) {
    try RestaurantMenuCatalog(data: Data(nonfinite.utf8), allowFictional: true)
  }
}

@Test func restaurantMenuErrorsContainNoPathsRawNutritionOrPermissionReferences() {
  for error in [RestaurantMenuCatalogError.invalidData, .fictionalNotAllowed] {
    #expect(!error.localizedDescription.contains("/"))
    #expect(!error.localizedDescription.contains("permissionReference"))
    #expect(!error.localizedDescription.contains("501.75"))
  }
}
