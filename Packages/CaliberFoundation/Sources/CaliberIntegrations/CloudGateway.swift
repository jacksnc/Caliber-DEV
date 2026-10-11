import CaliberDatabase
import Foundation
import Security

public enum GatewayError: Error, Equatable, Sendable {
  case unconfigured, insecureEndpoint, invalidResponse, unauthorized, unavailable, keychain
}
public struct CloudConfiguration: Sendable {
  public let endpoint: URL
  /// Requested function invocation region; this does not assert storage residency or failover policy.
  public let region: String?
  public init(endpoint: URL, region: String? = nil) throws {
    guard endpoint.scheme == "https", endpoint.host != nil, endpoint.user == nil,
      endpoint.password == nil,
      endpoint.query == nil, endpoint.fragment == nil
    else { throw GatewayError.insecureEndpoint }
    if let region {
      guard
        let match = region.range(of: "^[a-z]{2}(?:-[a-z]+)+-[0-9]+$", options: .regularExpression),
        match.lowerBound == region.startIndex, match.upperBound == region.endIndex
      else {
        throw GatewayError.insecureEndpoint
      }
    }
    self.endpoint = endpoint
    self.region = region
  }
}
/// `localOnly` means this device is cleared; remote refresh-token revocation was not confirmed.
public enum DeviceSignOutResult: Sendable, Equatable {
  case remoteRevoked, localOnly
}
public struct AuthSession: Codable, Sendable, Equatable {
  public let accessToken: String
  public let refreshToken: String
  public let subject: String
  public let expiresAt: Date
  public init(accessToken: String, refreshToken: String, subject: String, expiresAt: Date) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.subject = subject
    self.expiresAt = expiresAt
  }
}
public protocol GatewayHTTPClient: Sendable {
  func send(_ request: URLRequest) async throws -> (Data, Int)
}
/// Refuse redirects: a gateway response must not forward credentials to another endpoint.
final class GatewayRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
public struct URLSessionGatewayClient: GatewayHTTPClient {
  private let session: URLSession
  public init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(
      configuration: configuration, delegate: GatewayRedirectPolicy(), delegateQueue: nil)
  }
  public func send(_ request: URLRequest) async throws -> (Data, Int) {
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw GatewayError.invalidResponse }
    return (data, response.statusCode)
  }
}
/// Token material never enters defaults, logs, crash context or the app bundle.
public protocol SessionStorage: Sendable {
  func save(_ session: AuthSession) async throws
  func load() async throws -> AuthSession?
  func clear() async throws
}
public actor SessionVault: SessionStorage {
  private let service: String
  public init(service: String = "Caliber.Foundation.Session") { self.service = service }
  public func save(_ session: AuthSession) throws {
    let data = try JSONEncoder().encode(session)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: "session",
    ]
    let update = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if update == errSecItemNotFound {
      var attributes = query
      attributes[kSecValueData as String] = data
      attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
        throw GatewayError.keychain
      }
    } else if update != errSecSuccess {
      throw GatewayError.keychain
    }
  }
  public func load() throws -> AuthSession? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: "session", kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else { throw GatewayError.keychain }
    guard let value = try? JSONDecoder().decode(AuthSession.self, from: data) else {
      throw GatewayError.keychain
    }
    return value
  }
  public func clear() throws {
    let status = SecItemDelete(
      [
        kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
        kSecAttrAccount as String: "session",
      ] as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw GatewayError.keychain
    }
  }
}

public actor CloudGateway: SyncTransport {
  private let configuration: CloudConfiguration?
  private let http: any GatewayHTTPClient
  private let vault: any SessionStorage
  private var generation = UUID()
  private var refreshTask: Task<AuthSession, Error>?
  private var mutationTask: Task<Void, Error>?
  private var signedOut = false
  public init(
    configuration: CloudConfiguration?, http: any GatewayHTTPClient = URLSessionGatewayClient(),
    vault: any SessionStorage = SessionVault()
  ) {
    self.configuration = configuration
    self.http = http
    self.vault = vault
  }
  public func signIn(email: String, password: String) async throws -> AuthSession {
    generation = UUID()
    let attempt = generation
    refreshTask?.cancel()
    refreshTask = nil
    struct Request: Encodable {
      let email: String
      let password: String
    }
    let session: AuthSession = try await request(
      "auth/sign-in", body: Request(email: email, password: password), token: nil)
    try validate(session)
    guard attempt == generation else { throw GatewayError.unauthorized }
    let save = enqueueMutation(session)
    try await save.value
    guard attempt == generation else { throw GatewayError.unauthorized }
    signedOut = false
    return session
  }
  /// Empty storage is normal. Only an expired access token requires a server request.
  public func restoredSession() async throws -> AuthSession? {
    let attempt = generation
    guard !signedOut else { return nil }
    if let mutationTask { try await mutationTask.value }
    guard attempt == generation, !signedOut else { throw GatewayError.unauthorized }
    let stored = try await vault.load()
    guard attempt == generation, !signedOut else { throw GatewayError.unauthorized }
    guard let stored else { return nil }
    try validateStored(stored)
    if stored.expiresAt <= Date().addingTimeInterval(60) {
      let refreshed = try await refresh()
      guard attempt == generation, !signedOut else { throw GatewayError.unauthorized }
      return refreshed
    }
    return stored
  }
  public func refresh() async throws -> AuthSession {
    guard !signedOut else { throw GatewayError.unauthorized }
    if let refreshTask { return try await refreshTask.value }
    let attempt = generation
    let task = Task { try await self.performRefresh(generation: attempt) }
    refreshTask = task
    defer { if generation == attempt { refreshTask = nil } }
    return try await task.value
  }
  private func performRefresh(generation attempt: UUID) async throws -> AuthSession {
    if let mutationTask { try await mutationTask.value }
    guard attempt == generation, !signedOut else { throw GatewayError.unauthorized }
    guard let previous = try await vault.load(), attempt == generation, !signedOut else {
      throw GatewayError.unauthorized
    }
    struct Request: Encodable { let refreshToken: String }
    let next: AuthSession = try await request(
      "auth/refresh", body: Request(refreshToken: previous.refreshToken), token: nil)
    try validate(next)
    guard attempt == generation else { throw GatewayError.unauthorized }
    guard next.subject == previous.subject else {
      try await signOut()
      throw GatewayError.unauthorized
    }
    let save = enqueueMutation(next)
    try await save.value
    guard attempt == generation, !signedOut else { throw GatewayError.unauthorized }
    return next
  }
  /// Local-only sign-out remains available offline and never makes an HTTP request.
  public func signOut() async throws {
    invalidateAuthentication()
    let clear = enqueueMutation(nil)
    try await clear.value
  }
  /// Clears this device first, then revokes only the captured old session.
  /// Newer logins can proceed during the request; its completion never edits storage.
  public func signOutOnThisDevice() async throws -> DeviceSignOutResult {
    invalidateAuthentication()
    let prior = mutationTask
    let storage = vault
    // Capture AND clear are one queue entry, behind a prior save and before any newer save.
    let capture = Task<AuthSession?, Error> {
      if let prior { _ = try? await prior.value }
      let previous = try? await storage.load()
      try await storage.clear()
      return previous
    }
    mutationTask = Task { _ = try await capture.value }
    guard let previous = try await capture.value else { return .localOnly }
    struct Request: Encodable {}
    struct Reply: Decodable { let signedOut: Bool }
    do {
      let reply: Reply = try await request(
        "auth/sign-out", body: Request(), token: previous.accessToken)
      return reply.signedOut ? .remoteRevoked : .localOnly
    } catch {
      // Local clearing has committed. Provider/network details must not surface here.
      return .localOnly
    }
  }
  private func invalidateAuthentication() {
    generation = UUID()
    refreshTask?.cancel()
    refreshTask = nil
    signedOut = true
  }
  /// Queue before suspending. A slow save must finish before the later sign-out clear,
  /// and an even newer login must save after that clear. Completion never clears a newer login.
  private func enqueueMutation(_ session: AuthSession?) -> Task<Void, Error> {
    let prior = mutationTask
    let storage = vault
    let task = Task {
      if let prior { _ = try? await prior.value }
      if let session { try await storage.save(session) } else { try await storage.clear() }
    }
    mutationTask = task
    return task
  }
  public func push(_ operations: [SyncOperation], ownerID: String) async throws
    -> [SyncAcknowledgement]
  {
    struct Request: Encodable {
      let ownerID: String
      let operations: [SyncOperation]
    }
    let token = try await accessToken()
    return try await request(
      "sync/push", body: Request(ownerID: ownerID, operations: operations), token: token.value,
      authenticatedGeneration: token.generation)
  }
  public func pull(ownerID: String, after: Int64, limit: Int) async throws -> SyncPage {
    struct Request: Encodable {
      let ownerID: String
      let after: Int64
      let limit: Int
    }
    let token = try await accessToken()
    return try await request(
      "sync/pull", body: Request(ownerID: ownerID, after: after, limit: max(1, min(limit, 100))),
      token: token.value, authenticatedGeneration: token.generation)
  }
  private func accessToken() async throws -> (value: String, generation: UUID) {
    guard configuration != nil else { throw GatewayError.unconfigured }
    let attempt = generation
    guard let session = try await restoredSession(), attempt == generation, !signedOut else {
      throw GatewayError.unauthorized
    }
    return (session.accessToken, attempt)
  }
  private func validateStored(_ session: AuthSession) throws {
    guard !session.accessToken.isEmpty, !session.refreshToken.isEmpty,
      UUID(uuidString: session.subject) != nil,
      session.expiresAt.timeIntervalSince1970.isFinite
    else { throw GatewayError.invalidResponse }
  }
  private func validate(_ session: AuthSession) throws {
    try validateStored(session)
    guard session.expiresAt > Date() else { throw GatewayError.invalidResponse }
  }
  private func request<Input: Encodable, Output: Decodable>(
    _ path: String, body: Input, token: String?, authenticatedGeneration: UUID? = nil
  ) async throws -> Output {
    guard let configuration else { throw GatewayError.unconfigured }
    var request = URLRequest(url: configuration.endpoint.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    if let region = configuration.region {
      request.setValue(region, forHTTPHeaderField: "x-region")
    }
    if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
    request.httpBody = try JSONEncoder().encode(body)
    let response: (Data, Int)
    if let authenticatedGeneration {
      guard authenticatedGeneration == generation, !signedOut else {
        throw GatewayError.unauthorized
      }
    }
    do { response = try await http.send(request) } catch { throw GatewayError.unavailable }
    guard response.0.count <= 10_000_000 else { throw GatewayError.invalidResponse }
    if response.1 == 401 || response.1 == 403 { throw GatewayError.unauthorized }
    guard (200..<300).contains(response.1) else { throw GatewayError.unavailable }
    guard let result = try? JSONDecoder().decode(Output.self, from: response.0) else {
      throw GatewayError.invalidResponse
    }
    return result
  }
}
