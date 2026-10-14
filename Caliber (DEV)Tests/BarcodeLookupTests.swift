import Foundation
import Testing

@testable import Caliber__DEV_

/// Every product and contact in this suite is fictional. The injected
/// transport records requests in memory and never opens a network connection.
@MainActor
@Suite("Barcode provider parsing and privacy")
struct BarcodeLookupTests {
  private let barcode = "0000000000017"

  @Test("A complete v3.6 per-serving label preserves fractions and total carbohydrate")
  func servingNutrition() async throws {
    let fake = try BarcodeFixtureTransport(data: fixture())
    let service = try provider(fake)
    let product = try await service.lookupFood(barcode: barcode)
    #expect(product.name == "Fictional Test Cereal")
    #expect(product.barcode == barcode)
    #expect(product.calories == 120.5)
    #expect(product.proteinGrams == 3.25)
    #expect(product.carbGrams == 22.75)
    #expect(product.fatGrams == 1.625)
    #expect(product.basisGrams == 30)
    #expect(product.basisDescription == "1 serving (30 g) · as sold")
    #expect(product.attribution.contains("Community data"))
    #expect(product.attribution.contains("ODbL"))
    #expect(product.sourceURL.host == "world.openfoodfacts.org")
    #expect(product.brand == nil)
  }

  @Test("A lookup requests only the barcode and required fields from the fixed staging host")
  func minimalRequest() async throws {
    let fake = try BarcodeFixtureTransport(data: fixture())
    _ = try await provider(fake).lookupFood(barcode: barcode)
    let request = try #require(fake.requests.first)
    #expect(request.httpMethod == "GET")
    #expect(request.httpBody == nil)
    #expect(request.url?.scheme == "https")
    #expect(request.url?.host == "world.openfoodfacts.net")
    #expect(request.url?.path == "/api/v3.6/product/0000000000017.json")
    #expect(
      request.value(forHTTPHeaderField: "User-Agent") == "CaliberDEV/0.1 (qa@caliber.invalid)")
    #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic b2ZmOm9mZg==")
    #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
    #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    let url = try #require(request.url)
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    #expect(query.map(\.name) == ["fields"])
    #expect(query.first?.value == "code,schema_version,product_name,product_name_en,nutrition")
  }

  @Test("Production does not receive the shared staging credentials")
  func productionRequest() async throws {
    let fake = try BarcodeFixtureTransport(data: fixture())
    let service = try OpenFoodFactsBarcodeService(
      contactEmail: "qa@caliber.invalid", environment: .production, transport: fake)
    _ = try await service.lookupFood(barcode: barcode)
    #expect(fake.requests.first?.url?.host == "world.openfoodfacts.org")
    #expect(fake.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test("Missing nutrients and net-carbohydrate-only labels never become zero or total carbs")
  func incompleteLabel() async throws {
    for change in [
      "missing", "netOnly", "modifier", "badUnit", "missingKcal", "estimate", "prepared",
      "ambiguous",
    ] {
      let fake = try BarcodeFixtureTransport(data: fixture(change))
      let service = try provider(fake)
      await #expect(throws: BarcodeLookupError.incompleteNutrition) {
        try await service.lookupFood(barcode: barcode)
      }
    }
  }

  @Test("Explicit zeros are valid; unknown or contradictory basis is not")
  func basisAndZeros() async throws {
    let zero = try BarcodeFixtureTransport(data: fixture("zero"))
    let product = try await provider(zero).lookupFood(barcode: barcode)
    #expect(product.fatGrams == 0)
    for change in ["missingBasis", "volumeAsMass", "contradictoryBasis", "negative", "tooLarge"] {
      let fake = try BarcodeFixtureTransport(data: fixture(change))
      await #expect(throws: BarcodeLookupError.incompleteNutrition) {
        try await provider(fake).lookupFood(barcode: barcode)
      }
    }
  }

  @Test("Volume stays volume, and an explicit 100 gram basis stays mass")
  func volumeAndMass() async throws {
    let volume = try BarcodeFixtureTransport(data: fixture("100ml"))
    let liquid = try await provider(volume).lookupFood(barcode: barcode)
    #expect(liquid.basisDescription == "100 ml · as sold")
    #expect(liquid.basisGrams == nil)
    let mass = try BarcodeFixtureTransport(data: fixture("100g"))
    let solid = try await provider(mass).lookupFood(barcode: barcode)
    #expect(solid.basisDescription == "100 g · as sold")
    #expect(solid.basisGrams == 100)
    let serving = try BarcodeFixtureTransport(data: fixture("servingMl"))
    #expect(try await provider(serving).lookupFood(barcode: barcode).basisGrams == nil)
  }

  @Test("A complete serving takes priority over a complete 100 gram input set")
  func servingPriority() async throws {
    let fake = try BarcodeFixtureTransport(data: fixture("twoBases"))
    let result = try await provider(fake).lookupFood(barcode: barcode)
    #expect(result.basisGrams == 30)
    #expect(result.calories == 120.5)
  }

  @Test("Corrupt JSON, wrong product identity, old schema and unexpected MIME are rejected")
  func malformedResponse() async throws {
    for change in ["wrongCode", "oldSchema", "stringValue", "booleanValue"] {
      let fake = try BarcodeFixtureTransport(data: fixture(change))
      await #expect(throws: BarcodeLookupError.invalidResponse) {
        try await provider(fake).lookupFood(barcode: barcode)
      }
    }
    let malformed = BarcodeFixtureTransport(raw: Data("not json".utf8))
    await #expect(throws: BarcodeLookupError.invalidResponse) {
      try await provider(malformed).lookupFood(barcode: barcode)
    }
    let html = BarcodeFixtureTransport(raw: try fixture(), mimeType: "text/html")
    await #expect(throws: BarcodeLookupError.invalidResponse) {
      try await provider(html).lookupFood(barcode: barcode)
    }
    let huge = BarcodeFixtureTransport(raw: Data(repeating: 32, count: 512 * 1024 + 1))
    await #expect(throws: BarcodeLookupError.invalidResponse) {
      try await provider(huge).lookupFood(barcode: barcode)
    }
  }

  @Test("Not found, provider downtime, redirects and offline errors are distinct")
  func transportErrors() async throws {
    let missing = BarcodeFixtureTransport(raw: Data(), status: 404)
    await #expect(throws: BarcodeLookupError.notFound) {
      try await provider(missing).lookupFood(barcode: barcode)
    }
    let downtime = BarcodeFixtureTransport(raw: Data(), status: 503)
    await #expect(throws: BarcodeLookupError.providerUnavailable) {
      try await provider(downtime).lookupFood(barcode: barcode)
    }
    let redirect = BarcodeFixtureTransport(raw: Data(), status: 302)
    await #expect(throws: BarcodeLookupError.invalidResponse) {
      try await provider(redirect).lookupFood(barcode: barcode)
    }
    let offline = BarcodeFixtureTransport(raw: Data(), error: URLError(.notConnectedToInternet))
    await #expect(throws: BarcodeLookupError.offline) {
      try await provider(offline).lookupFood(barcode: barcode)
    }
    #expect(redirect.requests.count == 1)
  }

  @Test("Ten requests per minute and the provider's Retry-After stop additional traffic")
  func throttling() async throws {
    let clock = BarcodeTestClock()
    let fake = try BarcodeFixtureTransport(data: fixture())
    let service = try provider(fake, now: { clock.time })
    for _ in 0..<10 { _ = try await service.lookupFood(barcode: barcode) }
    await #expect(throws: BarcodeLookupError.rateLimited(retryAfterSeconds: 60)) {
      try await service.lookupFood(barcode: barcode)
    }
    #expect(fake.requests.count == 10)
    clock.time += 60
    _ = try await service.lookupFood(barcode: barcode)
    #expect(fake.requests.count == 11)
    let limited = BarcodeFixtureTransport(raw: Data(), status: 429, retryAfter: "90")
    let busy = try provider(limited, now: { clock.time })
    await #expect(throws: BarcodeLookupError.rateLimited(retryAfterSeconds: 90)) {
      try await busy.lookupFood(barcode: barcode)
    }
    clock.time += 10
    await #expect(throws: BarcodeLookupError.rateLimited(retryAfterSeconds: 80)) {
      try await busy.lookupFood(barcode: barcode)
    }
    #expect(limited.requests.count == 1)
  }

  @Test("Unconfigured services and invalid codes never send requests")
  func disabledAndInvalidInput() async throws {
    await #expect(throws: BarcodeLookupError.configurationRequired) {
      try await DisabledBarcodeService().lookupFood(barcode: barcode)
    }
    let fake = try BarcodeFixtureTransport(data: fixture())
    for contact in [
      "", "https://example.com", "test@example.com\n", "test@example.com\r\nCookie: bad",
    ] {
      #expect(throws: BarcodeLookupError.configurationRequired) {
        try OpenFoodFactsBarcodeService(contactEmail: contact, transport: fake)
      }
    }
    let service = try provider(fake)
    for code in [
      "123", "0000000000017/../../", " 0000000000017", "１２３４５６７８", "1234567a", "012345678906",
    ] {
      await #expect(throws: BarcodeLookupError.invalidBarcode) {
        try await service.lookupFood(barcode: code)
      }
    }
    #expect(fake.requests.isEmpty)
  }

  @Test("OFF's documented leading-zero normalization keeps the scanned UPC intact")
  func leadingZeroNormalization() async throws {
    let fake = try BarcodeFixtureTransport(data: fixture())
    let product = try await provider(fake).lookupFood(barcode: "000000000017")
    #expect(product.barcode == "000000000017")
    #expect(fake.requests.first?.url?.path.contains("000000000017.json") == true)
  }

  private func provider(
    _ fake: BarcodeFixtureTransport, now: @escaping () -> TimeInterval = { 1000 }
  ) throws -> OpenFoodFactsBarcodeService {
    try OpenFoodFactsBarcodeService(contactEmail: "qa@caliber.invalid", transport: fake, now: now)
  }

  private func fixture(_ change: String = "") throws -> Data {
    var nutrients: [String: Any] = [
      "energy-kcal": ["value": 120.5, "unit": "kcal"],
      "proteins": ["value": 3.25, "unit": "g"],
      "carbohydrates-total": ["value": 22.75, "unit": "g"],
      "carbohydrates": ["value": 18.75, "unit": "g"],
      "fat": ["value": 1.625, "unit": "g"],
    ]
    switch change {
    case "missing": nutrients.removeValue(forKey: "proteins")
    case "netOnly": nutrients.removeValue(forKey: "carbohydrates-total")
    case "modifier": nutrients["fat"] = ["value": 0.5, "unit": "g", "modifier": "<"]
    case "badUnit": nutrients["proteins"] = ["value": 3.25, "unit": "mg"]
    case "missingKcal":
      nutrients.removeValue(forKey: "energy-kcal")
      nutrients["energy-kj"] = ["value": 500, "unit": "kJ"]
    case "zero": nutrients["fat"] = ["value": 0, "unit": "g"]
    case "negative": nutrients["fat"] = ["value": -1, "unit": "g"]
    case "tooLarge": nutrients["fat"] = ["value": 1000, "unit": "g"]
    case "stringValue": nutrients["fat"] = ["value": "1.625", "unit": "g"]
    case "booleanValue": nutrients["fat"] = ["value": true, "unit": "g"]
    default: break
    }
    var set: [String: Any] = [
      "preparation": "as_sold", "source": "packaging", "per": "serving", "per_quantity": 30,
      "per_unit": "g", "nutrients": nutrients,
    ]
    switch change {
    case "estimate": set["source"] = "estimate"
    case "prepared": set["preparation"] = "prepared"
    case "missingBasis": set.removeValue(forKey: "per_quantity")
    case "volumeAsMass": set["per_unit"] = "unknown"
    case "100ml":
      set["per"] = "100ml"
      set["per_quantity"] = 100
      set["per_unit"] = "ml"
    case "100g":
      set["per"] = "100g"
      set["per_quantity"] = 100
    case "contradictoryBasis":
      set["per"] = "100g"
      set["per_quantity"] = 100
      set["per_unit"] = "ml"
    case "servingMl": set["per_unit"] = "ml"
    default: break
    }
    var sets = [set]
    if change == "ambiguous" { sets.append(set) }
    if change == "twoBases" {
      var hundred = set
      hundred["per"] = "100g"
      hundred["per_quantity"] = 100
      sets.append(hundred)
    }
    let product: [String: Any] = [
      "code": change == "wrongCode" ? "0000000000024" : barcode,
      "schema_version": change == "oldSchema" ? 1002 : 1004,
      "product_name": "Fictional Test Cereal",
      "nutrition": ["input_sets": sets],
    ]
    return try JSONSerialization.data(withJSONObject: ["status": "success", "product": product])
  }
}

@MainActor
private final class BarcodeTestClock { var time: TimeInterval = 1000 }

@MainActor
private final class BarcodeFixtureTransport: BarcodeHTTPTransport {
  private let response: BarcodeHTTPResponse
  private let error: Error?
  var requests: [URLRequest] = []
  convenience init(data: Data) throws { self.init(raw: data) }
  init(
    raw: Data, status: Int = 200, mimeType: String = "application/json", retryAfter: String? = nil,
    error: Error? = nil
  ) {
    response = BarcodeHTTPResponse(
      data: raw, statusCode: status, mimeType: mimeType, retryAfter: retryAfter)
    self.error = error
  }
  func send(_ request: URLRequest) async throws -> BarcodeHTTPResponse {
    requests.append(request)
    if let error { throw error }
    return response
  }
}
