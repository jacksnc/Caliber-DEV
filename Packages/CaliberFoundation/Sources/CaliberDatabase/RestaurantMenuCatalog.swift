import Foundation

/// A permission declaration supplied by the dataset owner. Parsing an approved declaration
/// cannot establish that a genuine legal review or permission grant has taken place.
public struct RestaurantMenuCatalogLicense: Equatable, Sendable {
  public let status: String
  public let permissionReference: String
  public let attribution: String
}

public struct RestaurantMenuCatalogSource: Equatable, Sendable {
  public let id: String
  public let name: String
  public let url: String
  public let retrievedOn: String
  public let license: RestaurantMenuCatalogLicense
}

/// All nutrients are for the listed serving. Missing grams stay unknown; this reader never
/// infers a density, converts a household measure or recomputes the source's calories.
public struct RestaurantMenuCatalogItem: Equatable, Sendable {
  public let id: String
  public let name: String
  public let category: String
  public let servingDescription: String
  public let servingGrams: Double?
  public let calories: Double
  public let proteinGrams: Double
  public let carbGrams: Double
  public let fatGrams: Double
}

public struct RestaurantMenuCatalogRestaurant: Equatable, Sendable {
  public let id: String
  public let name: String
  public let sourceID: String
  public let items: [RestaurantMenuCatalogItem]
}

public enum RestaurantMenuCatalogError: LocalizedError, Equatable, Sendable {
  case invalidData
  case fictionalNotAllowed

  public var errorDescription: String? {
    switch self {
    case .invalidData:
      "The restaurant menu data could not be verified. You can add your own menu item."
    case .fictionalNotAllowed:
      "Fictional restaurant menu data is available only in an explicitly enabled preview."
    }
  }
}

/// A bounded, immutable restaurant registry. No user data, downloads, persistence or legal
/// approval workflow is performed here. Empty production registries are valid.
public struct RestaurantMenuCatalog: Equatable, Sendable {
  public let schemaVersion: Int
  public let fictional: Bool
  /// Digest of the importer's original input bytes, not proof that permissions were reviewed.
  public let inputSHA256: String
  public let sources: [RestaurantMenuCatalogSource]
  public let restaurants: [RestaurantMenuCatalogRestaurant]

  public init(data: Data, allowFictional: Bool = false) throws {
    guard !data.isEmpty, data.count <= 5_000_000 else {
      throw RestaurantMenuCatalogError.invalidData
    }
    do {
      // JSONDecoder otherwise silently accepts duplicate keys and ignores unknown keys.
      var scanner = MenuJSONDuplicateScanner(bytes: Array(data))
      try scanner.validate()
      let object = try JSONSerialization.jsonObject(with: data)
      try Self.validateShape(object)
      let document = try JSONDecoder().decode(MenuDocument.self, from: data)
      guard document.schemaVersion == 1, Self.isDigest(document.inputSHA256) else {
        throw RestaurantMenuCatalogError.invalidData
      }
      guard !document.fictional || allowFictional else {
        throw RestaurantMenuCatalogError.fictionalNotAllowed
      }
      var sourceIDs: Set<String> = []
      let decodedSources = try document.sources.map { source in
        guard Self.identifier(source.id), sourceIDs.insert(source.id).inserted,
          Self.text(source.name, maximum: 200),
          Self.sourceURL(source.url, fictional: document.fictional),
          Self.date(source.retrievedOn),
          source.license.status == (document.fictional ? "fixture" : "approved"),
          Self.text(source.license.permissionReference, maximum: 1_000),
          Self.text(source.license.attribution, maximum: 1_000)
        else { throw RestaurantMenuCatalogError.invalidData }
        return RestaurantMenuCatalogSource(
          id: source.id, name: source.name, url: source.url, retrievedOn: source.retrievedOn,
          license: RestaurantMenuCatalogLicense(
            status: source.license.status, permissionReference: source.license.permissionReference,
            attribution: source.license.attribution))
      }
      var restaurantIDs: Set<String> = []
      var itemIDs: Set<String> = []
      let decodedRestaurants = try document.restaurants.map { restaurant in
        guard Self.identifier(restaurant.id), restaurantIDs.insert(restaurant.id).inserted,
          Self.text(restaurant.name, maximum: 200), sourceIDs.contains(restaurant.sourceID)
        else { throw RestaurantMenuCatalogError.invalidData }
        let items = try restaurant.items.map { item in
          guard Self.identifier(item.id), itemIDs.insert(item.id).inserted,
            Self.text(item.name, maximum: 200),
            ["appetizer", "entree", "side", "drink", "dessert"].contains(item.category),
            Self.text(item.servingDescription, maximum: 300),
            item.servingGrams.map({ $0.isFinite && $0 > 0 && $0 <= 1_000_000 }) ?? true,
            [item.calories, item.proteinGrams, item.carbGrams, item.fatGrams].allSatisfy({
              $0.isFinite && (0...1_000_000).contains($0)
            })
          else { throw RestaurantMenuCatalogError.invalidData }
          return RestaurantMenuCatalogItem(
            id: item.id, name: item.name, category: item.category,
            servingDescription: item.servingDescription, servingGrams: item.servingGrams,
            calories: item.calories, proteinGrams: item.proteinGrams,
            carbGrams: item.carbGrams, fatGrams: item.fatGrams)
        }
        return RestaurantMenuCatalogRestaurant(
          id: restaurant.id, name: restaurant.name, sourceID: restaurant.sourceID, items: items)
      }
      schemaVersion = document.schemaVersion
      fictional = document.fictional
      inputSHA256 = document.inputSHA256
      sources = decodedSources
      restaurants = decodedRestaurants
    } catch let error as RestaurantMenuCatalogError {
      throw error
    } catch {
      throw RestaurantMenuCatalogError.invalidData
    }
  }

  public func restaurant(id: String) -> RestaurantMenuCatalogRestaurant? {
    restaurants.first { $0.id == id }
  }

  /// Exact name matching folds case, accents and character width without merging IDs or items.
  public func restaurants(named name: String) -> [RestaurantMenuCatalogRestaurant] {
    guard Self.text(name, maximum: 200) else { return [] }
    let target = Self.normalizedName(name)
    return restaurants.filter { Self.normalizedName($0.name) == target }
  }

  private static func validateShape(_ value: Any) throws {
    let top = try object(
      value, keys: ["schemaVersion", "fictional", "inputSHA256", "sources", "restaurants"])
    guard let sources = top["sources"] as? [Any], sources.count <= 100,
      let restaurants = top["restaurants"] as? [Any], restaurants.count <= 100
    else { throw RestaurantMenuCatalogError.invalidData }
    for value in sources {
      let source = try object(value, keys: ["id", "name", "url", "retrievedOn", "license"])
      guard let license = source["license"] else { throw RestaurantMenuCatalogError.invalidData }
      _ = try object(license, keys: ["status", "permissionReference", "attribution"])
    }
    var count = 0
    for value in restaurants {
      let restaurant = try object(value, keys: ["id", "name", "sourceID", "items"])
      guard let items = restaurant["items"] as? [Any], items.count <= 1_000 else {
        throw RestaurantMenuCatalogError.invalidData
      }
      count += items.count
      guard count <= 10_000 else { throw RestaurantMenuCatalogError.invalidData }
      for value in items {
        _ = try object(
          value,
          keys: [
            "id", "name", "category", "servingDescription", "servingGrams", "calories",
            "proteinGrams",
            "carbGrams", "fatGrams",
          ])
      }
    }
  }

  private static func object(_ value: Any, keys: Set<String>) throws -> [String: Any] {
    guard let object = value as? [String: Any], Set(object.keys) == keys else {
      throw RestaurantMenuCatalogError.invalidData
    }
    return object
  }

  private static func identifier(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard (1...96).contains(bytes.count), let first = bytes.first,
      (97...122).contains(first) || (48...57).contains(first)
    else { return false }
    return bytes.allSatisfy {
      (97...122).contains($0) || (48...57).contains($0) || [45, 46, 58, 95].contains($0)
    }
  }

  private static func text(_ value: String, maximum: Int) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && value.unicodeScalars.count <= maximum
      && !value.unicodeScalars.contains(where: { prohibited($0) })
  }

  private static func sourceURL(_ value: String, fictional: Bool) -> Bool {
    guard value.hasPrefix("https://"), value.unicodeScalars.count <= 2_000,
      !value.contains("\\"),
      !value.unicodeScalars.contains(where: {
        CharacterSet.whitespacesAndNewlines.contains($0)
          || prohibited($0)
      }), let url = URLComponents(string: value), url.scheme == "https",
      url.user == nil, url.password == nil, let rawHost = url.host?.lowercased(), !rawHost.isEmpty
    else { return false }
    let host = rawHost
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard host.contains("."), url.percentEncodedHost?.lowercased() == host,
      url.port.map({ (1...65_535).contains($0) }) ?? true,
      host.utf8.allSatisfy({
        (97...122).contains($0) || (48...57).contains($0) || [45, 46].contains($0)
      }),
      labels.allSatisfy({
        !$0.isEmpty && $0.utf8.count <= 63 && !$0.hasPrefix("-") && !$0.hasSuffix("-")
      })
    else { return false }
    guard !fictional else { return true }
    return !["example.com", "example.org", "example.net"].contains(host)
      && !["invalid", "test", "example"].contains(where: { host == $0 || host.hasSuffix("." + $0) })
  }

  private static func prohibited(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.properties.generalCategory {
    case .control, .format, .surrogate, .privateUse, .unassigned: true
    default: false
    }
  }

  private static func normalizedName(_ value: String) -> String {
    let locale = Locale(identifier: "en_US_POSIX")
    return value.decomposedStringWithCompatibilityMapping.folding(
      options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale
    ).lowercased(with: locale).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func date(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
      bytes.enumerated().allSatisfy({
        $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element)
      }),
      let year = Int(value.prefix(4)), year > 0,
      let month = Int(value.dropFirst(5).prefix(2)), (1...12).contains(month),
      let day = Int(value.suffix(2)), day > 0
    else { return false }
    let leap = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
    return day <= [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
  }

  private static func isDigest(_ value: String) -> Bool {
    value.utf8.count == 64
      && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }
}

private struct MenuDocument: Decodable {
  let schemaVersion: Int
  let fictional: Bool
  let inputSHA256: String
  let sources: [MenuSource]
  let restaurants: [MenuRestaurant]
}

private struct MenuSource: Decodable {
  let id: String
  let name: String
  let url: String
  let retrievedOn: String
  let license: MenuLicense
}

private struct MenuLicense: Decodable {
  let status: String
  let permissionReference: String
  let attribution: String
}

private struct MenuRestaurant: Decodable {
  let id: String
  let name: String
  let sourceID: String
  let items: [MenuItem]
}

private struct MenuItem: Decodable {
  let id: String
  let name: String
  let category: String
  let servingDescription: String
  let servingGrams: Double?
  let calories: Double
  let proteinGrams: Double
  let carbGrams: Double
  let fatGrams: Double
}

/// A small lexical pass detects duplicate object keys before Foundation collapses them.
/// JSONDecoder performs final syntax/type validation; nesting is bounded before either decode.
private struct MenuJSONDuplicateScanner {
  let bytes: [UInt8]
  private var index = 0

  init(bytes: [UInt8]) { self.bytes = bytes }

  mutating func validate() throws {
    try value(depth: 0)
    whitespace()
    guard index == bytes.count else { throw RestaurantMenuCatalogError.invalidData }
  }

  private mutating func value(depth: Int) throws {
    whitespace()
    guard depth <= 24, index < bytes.count else { throw RestaurantMenuCatalogError.invalidData }
    switch bytes[index] {
    case 123:
      index += 1
      whitespace()
      if consume(125) { return }
      var keys: Set<String> = []
      while true {
        whitespace()
        let key = try string(decode: true)
        guard keys.insert(key).inserted else { throw RestaurantMenuCatalogError.invalidData }
        whitespace()
        guard consume(58) else { throw RestaurantMenuCatalogError.invalidData }
        try value(depth: depth + 1)
        whitespace()
        if consume(125) { return }
        guard consume(44) else { throw RestaurantMenuCatalogError.invalidData }
      }
    case 91:
      index += 1
      whitespace()
      if consume(93) { return }
      while true {
        try value(depth: depth + 1)
        whitespace()
        if consume(93) { return }
        guard consume(44) else { throw RestaurantMenuCatalogError.invalidData }
      }
    case 34:
      _ = try string(decode: false)
    default:
      let start = index
      while index < bytes.count, ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) { index += 1 }
      guard index > start, index - start <= 128 else {
        throw RestaurantMenuCatalogError.invalidData
      }
    }
  }

  private mutating func string(decode: Bool) throws -> String {
    let start = index
    guard consume(34) else { throw RestaurantMenuCatalogError.invalidData }
    var escaped = false
    while index < bytes.count {
      switch bytes[index] {
      case 34:
        index += 1
        guard decode else { return "" }
        if !escaped {
          guard let key = String(bytes: bytes[(start + 1)..<(index - 1)], encoding: .utf8) else {
            throw RestaurantMenuCatalogError.invalidData
          }
          return key
        }
        return try JSONDecoder().decode(String.self, from: Data(bytes[start..<index]))
      case 92:
        escaped = true
        index += 2
      default:
        guard bytes[index] >= 32 else { throw RestaurantMenuCatalogError.invalidData }
        index += 1
      }
    }
    throw RestaurantMenuCatalogError.invalidData
  }

  private mutating func consume(_ byte: UInt8) -> Bool {
    guard index < bytes.count, bytes[index] == byte else { return false }
    index += 1
    return true
  }

  private mutating func whitespace() {
    while index < bytes.count, [9, 10, 13, 32].contains(bytes[index]) { index += 1 }
  }
}
