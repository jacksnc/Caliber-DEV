import Foundation

struct BarcodeHTTPResponse {
  let data: Data
  let statusCode: Int
  let mimeType: String?
  let retryAfter: String?
}

@MainActor
protocol BarcodeHTTPTransport {
  func send(_ request: URLRequest) async throws -> BarcodeHTTPResponse
}

/// Optional adapter, absent from the default app factory. Development defaults
/// to OFF's documented staging host. It requires a real owner-supplied contact.
@MainActor
final class OpenFoodFactsBarcodeService: BarcodeService {
  enum Environment {
    case staging
    case production
    var host: String { self == .staging ? "world.openfoodfacts.net" : "world.openfoodfacts.org" }
  }

  static let maximumResponseBytes = 512 * 1024
  private let environment: Environment
  private let transport: any BarcodeHTTPTransport
  private let userAgent: String
  private let now: () -> TimeInterval
  private var requestTimes: [TimeInterval] = []
  private var blockedUntil: TimeInterval = 0

  init(
    contactEmail: String, environment: Environment = .staging,
    transport: (any BarcodeHTTPTransport)? = nil,
    now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
  ) throws {
    // The official format is AppName/Version (ContactEmail); do not invent
    // a sender or silently replace the requested contact with a URL.
    guard contactEmail.utf8.count <= 254, contactEmail.utf8.allSatisfy({ (33...126).contains($0) }),
      contactEmail.range(
        of: #"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
        options: .regularExpression) != nil
    else { throw BarcodeLookupError.configurationRequired }
    self.environment = environment
    self.transport = transport ?? PrivateBarcodeHTTPTransport()
    self.userAgent = "CaliberDEV/0.1 (\(contactEmail))"
    self.now = now
  }

  func lookupFood(barcode: String) async throws -> BarcodeNutritionProduct {
    try Task.checkCancellation()
    guard Self.isSupportedBarcode(barcode) else { throw BarcodeLookupError.invalidBarcode }
    try admitRequest()
    let response: BarcodeHTTPResponse
    do {
      response = try await transport.send(makeRequest(barcode: barcode))
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as BarcodeLookupError {
      throw error
    } catch let error as URLError {
      try Task.checkCancellation()
      let offlineCodes: [URLError.Code] = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
      ]
      throw offlineCodes.contains(error.code) ? BarcodeLookupError.offline : .providerUnavailable
    } catch {
      throw BarcodeLookupError.providerUnavailable
    }
    try Task.checkCancellation()
    guard response.data.count <= Self.maximumResponseBytes else {
      throw BarcodeLookupError.invalidResponse
    }
    switch response.statusCode {
    case 404: throw BarcodeLookupError.notFound
    case 429:
      let seconds = min(max(Int(response.retryAfter ?? "") ?? 60, 1), 3600)
      blockedUntil = now() + Double(seconds)
      throw BarcodeLookupError.rateLimited(retryAfterSeconds: seconds)
    case 200: break
    case 500...599: throw BarcodeLookupError.providerUnavailable
    default: throw BarcodeLookupError.invalidResponse
    }
    guard response.mimeType?.lowercased() == "application/json" else {
      throw BarcodeLookupError.invalidResponse
    }
    return try Self.parse(response.data, requestedBarcode: barcode)
  }

  private func makeRequest(barcode: String) throws -> URLRequest {
    var components = URLComponents()
    components.scheme = "https"
    components.host = environment.host
    components.path = "/api/v3.6/product/\(barcode).json"
    components.queryItems = [
      URLQueryItem(
        name: "fields", value: "code,schema_version,product_name,product_name_en,nutrition")
    ]
    guard let url = components.url else { throw BarcodeLookupError.configurationRequired }
    var request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    if environment == .staging {
      // Public anti-indexing credentials documented by OFF, not a user
      // account, private key, personal password or production session.
      request.setValue("Basic b2ZmOm9mZg==", forHTTPHeaderField: "Authorization")
    }
    return request
  }

  private func admitRequest() throws {
    let time = now()
    guard time.isFinite, time >= 0 else { throw BarcodeLookupError.configurationRequired }
    if blockedUntil > time {
      throw BarcodeLookupError.rateLimited(retryAfterSeconds: Int(ceil(blockedUntil - time)))
    }
    requestTimes.removeAll { time - $0 >= 60 }
    guard requestTimes.count < 10 else {
      let wait = Int(ceil(60 - (time - (requestTimes.first ?? time))))
      throw BarcodeLookupError.rateLimited(retryAfterSeconds: min(max(wait, 1), 60))
    }
    requestTimes.append(time)
  }

  private static func isSupportedBarcode(_ barcode: String) -> Bool {
    BarcodeValue.isValid(barcode) && !barcode.contains(where: { $0.isWhitespace })
  }

  private static func normalizedOFFCode(_ barcode: String) -> String {
    let digits = String(barcode.drop { $0 == "0" })
    let length = digits.count <= 8 ? 8 : max(13, digits.count)
    return String(repeating: "0", count: max(0, length - digits.count)) + digits
  }

  private static func parse(_ data: Data, requestedBarcode: String) throws
    -> BarcodeNutritionProduct
  {
    guard let envelope = try? JSONDecoder().decode(OFFEnvelope.self, from: data) else {
      throw BarcodeLookupError.invalidResponse
    }
    guard envelope.status == "success", envelope.errors?.isEmpty != false,
      envelope.warnings?.isEmpty != false
    else { throw BarcodeLookupError.incompleteNutrition }
    guard let product = envelope.product, product.schemaVersion == 1004,
      isSupportedBarcode(product.code),
      normalizedOFFCode(product.code) == normalizedOFFCode(requestedBarcode)
    else { throw BarcodeLookupError.invalidResponse }
    let name = (product.productNameEnglish ?? product.productName ?? "").trimmingCharacters(
      in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= 300 else { throw BarcodeLookupError.incompleteNutrition }
    let candidates = (product.nutrition?.inputSets ?? []).compactMap { set -> OFFCandidate? in
      // One complete, as-sold packaging/manufacturer set supplies every
      // macro. Aggregates can mix sources; estimates are not label facts.
      guard set.preparation == "as_sold", ["packaging", "manufacturer"].contains(set.source),
        let calories = set.nutrients["energy-kcal"]?.checkedValue(unit: "kcal"),
        let protein = set.nutrients["proteins"]?.checkedValue(unit: "g"),
        let carbs = set.nutrients["carbohydrates-total"]?.checkedValue(unit: "g"),
        let fat = set.nutrients["fat"]?.checkedValue(unit: "g")
      else { return nil }
      let basis: String
      let mass: Double?
      let rank: Int
      switch set.per {
      case "serving":
        guard let quantity = set.perQuantity, quantity.isFinite, quantity > 0, quantity <= 10_000,
          let unit = set.perUnit, ["g", "ml"].contains(unit)
        else { return nil }
        basis = "1 serving (\(Self.number(quantity)) \(unit)) · as sold"
        mass = unit == "g" ? quantity : nil
        rank = 0
      case "100g":
        guard set.perUnit == nil || set.perUnit == "g",
          set.perQuantity == nil || set.perQuantity == 100
        else { return nil }
        basis = "100 g · as sold"
        mass = 100
        rank = 10
      case "100ml":
        guard set.perUnit == nil || set.perUnit == "ml",
          set.perQuantity == nil || set.perQuantity == 100
        else { return nil }
        basis = "100 ml · as sold"
        mass = nil
        rank = 20
      default: return nil
      }
      let maxMacros = mass ?? (set.per == "100ml" ? 200 : 10_000)
      guard calories <= maxMacros * 10, [protein, carbs, fat].allSatisfy({ $0 <= maxMacros }) else {
        return nil
      }
      if let mass, protein + carbs + fat > mass * 1.05 { return nil }
      return OFFCandidate(
        rank: rank + (set.source == "manufacturer" ? 0 : 1), calories: calories,
        protein: protein, carbs: carbs, fat: fat, basis: basis, mass: mass)
    }.sorted { $0.rank < $1.rank }
    guard let selected = candidates.first,
      candidates.count == 1 || candidates[1].rank != selected.rank
    else { throw BarcodeLookupError.incompleteNutrition }
    guard let sourceURL = URL(string: "https://world.openfoodfacts.org/product/\(product.code)")
    else { throw BarcodeLookupError.invalidResponse }
    return BarcodeNutritionProduct(
      barcode: requestedBarcode, name: name, brand: nil,
      calories: selected.calories, proteinGrams: selected.protein, carbGrams: selected.carbs,
      fatGrams: selected.fat,
      basisDescription: selected.basis, basisGrams: selected.mass, sourceURL: sourceURL,
      sourceName: "Open Food Facts",
      attribution:
        "Open Food Facts contributors · ODbL 1.0 / DbCL 1.0 · Community data; check the package label."
    )
  }

  private static func number(_ value: Double) -> String {
    let text = String(value)
    return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
  }
}

private struct OFFEnvelope: Decodable {
  let status: String
  let product: OFFProduct?
  let errors: [OFFIssue]?
  let warnings: [OFFIssue]?
}
private struct OFFIssue: Decodable {}
private struct OFFProduct: Decodable {
  let code: String
  let schemaVersion: Int
  let productName: String?
  let productNameEnglish: String?
  let nutrition: OFFNutrition?
  enum CodingKeys: String, CodingKey {
    case code, nutrition
    case schemaVersion = "schema_version"
    case productName = "product_name"
    case productNameEnglish = "product_name_en"
  }
}
private struct OFFNutrition: Decodable {
  let inputSets: [OFFNutrientSet]?
  enum CodingKeys: String, CodingKey { case inputSets = "input_sets" }
}
private struct OFFNutrientSet: Decodable {
  let preparation: String
  let per: String
  let perQuantity: Double?
  let perUnit: String?
  let source: String
  let nutrients: [String: OFFNutrient]
  enum CodingKeys: String, CodingKey {
    case preparation, per, source, nutrients
    case perQuantity = "per_quantity"
    case perUnit = "per_unit"
  }
}
private struct OFFNutrient: Decodable {
  let value: Double?
  let unit: String?
  let modifier: String?
  func checkedValue(unit requiredUnit: String) -> Double? {
    guard let value, value.isFinite, value >= 0, unit == requiredUnit, modifier == nil else {
      return nil
    }
    return value
  }
}
private struct OFFCandidate {
  let rank: Int
  let calories: Double
  let protein: Double
  let carbs: Double
  let fat: Double
  let basis: String
  let mass: Double?
}

/// No cookies, credentials, disk cache, redirects or unbounded product bodies.
@MainActor
final class PrivateBarcodeHTTPTransport: BarcodeHTTPTransport {
  private let session: URLSession
  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.timeoutIntervalForRequest = 12
    configuration.timeoutIntervalForResource = 15
    configuration.waitsForConnectivity = false
    session = URLSession(
      configuration: configuration, delegate: BarcodeNoRedirectDelegate(), delegateQueue: nil)
  }
  deinit { session.invalidateAndCancel() }

  func send(_ request: URLRequest) async throws -> BarcodeHTTPResponse {
    guard let url = request.url, url.scheme == "https",
      ["world.openfoodfacts.org", "world.openfoodfacts.net"].contains(url.host ?? ""),
      request.httpMethod == "GET"
    else { throw BarcodeLookupError.configurationRequired }
    let (bytes, response) = try await session.bytes(for: request)
    defer { bytes.task.cancel() }
    guard let response = response as? HTTPURLResponse,
      response.expectedContentLength <= OpenFoodFactsBarcodeService.maximumResponseBytes
    else { throw BarcodeLookupError.invalidResponse }
    var data = Data()
    for try await byte in bytes {
      guard data.count < OpenFoodFactsBarcodeService.maximumResponseBytes else {
        throw BarcodeLookupError.invalidResponse
      }
      data.append(byte)
    }
    return BarcodeHTTPResponse(
      data: data, statusCode: response.statusCode, mimeType: response.mimeType,
      retryAfter: response.value(forHTTPHeaderField: "Retry-After"))
  }
}

private final class BarcodeNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable
{
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) { completionHandler(nil) }
}
