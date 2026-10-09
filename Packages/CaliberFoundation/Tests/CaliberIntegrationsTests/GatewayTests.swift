import Foundation
import Testing

@testable import CaliberIntegrations

@Test(arguments: [
  "http://example.com", "https://name:pass@example.com", "https://example.com?secret=x",
  "https://example.com#key",
])
func insecureConfigurationFailsClosed(_ value: String) {
  #expect(throws: GatewayError.insecureEndpoint) {
    try CloudConfiguration(endpoint: URL(string: value)!)
  }
}
@Test func missingConfigurationMakesNoNetworkRequest() async {
  let gateway = CloudGateway(configuration: nil)
  await #expect(throws: GatewayError.unconfigured) {
    try await gateway.signIn(email: "test@example.invalid", password: "never-transmitted")
  }
}
private struct FailureClient: GatewayHTTPClient {
  let status: Int
  func send(_ request: URLRequest) async throws -> (Data, Int) {
    (Data("private health data must not surface".utf8), status)
  }
}
@Test func responseBodiesNeverEscapeAsErrors() async throws {
  let configuration = try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!)
  let gateway = CloudGateway(configuration: configuration, http: FailureClient(status: 500))
  await #expect(throws: GatewayError.unavailable) {
    try await gateway.signIn(email: "test@example.invalid", password: "redacted")
  }
  let denied = CloudGateway(configuration: configuration, http: FailureClient(status: 401))
  await #expect(throws: GatewayError.unauthorized) {
    try await denied.signIn(email: "test@example.invalid", password: "redacted")
  }
}

private actor MemorySessionStorage: SessionStorage {
  var session: AuthSession?
  init(_ session: AuthSession? = nil) { self.session = session }
  func save(_ session: AuthSession) { self.session = session }
  func load() -> AuthSession? { session }
  func clear() { session = nil }
}
private actor PausedClient: GatewayHTTPClient {
  private var response: CheckedContinuation<(Data, Int), any Error>?
  private var started: CheckedContinuation<Void, Never>?
  private(set) var count = 0
  func send(_ request: URLRequest) async throws -> (Data, Int) {
    count += 1
    return try await withCheckedThrowingContinuation { continuation in
      response = continuation
      started?.resume()
      started = nil
    }
  }
  func waitUntilStarted() async {
    if count > 0 { return }
    await withCheckedContinuation { started = $0 }
  }
  func finish(_ session: AuthSession) throws {
    response?.resume(returning: (try JSONEncoder().encode(session), 200))
    response = nil
  }
}
private func fixtureSession() -> AuthSession {
  AuthSession(
    accessToken: "fictional-access", refreshToken: "fictional-refresh",
    subject: "00000000-0000-4000-8000-000000000001", expiresAt: Date().addingTimeInterval(3600))
}
@Test(.timeLimit(.minutes(1))) func signOutCannotBeUndoneByInFlightSignIn() async throws {
  let client = PausedClient()
  let storage = MemorySessionStorage()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let request = Task {
    try await gateway.signIn(email: "fixture@example.invalid", password: "fixture")
  }
  await client.waitUntilStarted()
  try await gateway.signOut()
  try await client.finish(fixtureSession())
  await #expect(throws: GatewayError.unauthorized) { try await request.value }
  #expect(await storage.load() == nil)
}
@Test(.timeLimit(.minutes(1))) func refreshRequestsShareOneTokenRotation() async throws {
  let client = PausedClient()
  let storage = MemorySessionStorage(fixtureSession())
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let first = Task { try await gateway.refresh() }
  await client.waitUntilStarted()
  let second = Task { try await gateway.refresh() }
  // Give the second caller an actor turn while the response is suspended.
  for _ in 0..<100 { await Task.yield() }
  let next = fixtureSession()
  try await client.finish(next)
  #expect(try await first.value == next)
  #expect(try await second.value == next)
  #expect(await client.count == 1)
}
@Test(.timeLimit(.minutes(1))) func signOutCannotBeUndoneByInFlightRefresh() async throws {
  let client = PausedClient()
  let storage = MemorySessionStorage(fixtureSession())
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let request = Task { try await gateway.refresh() }
  await client.waitUntilStarted()
  try await gateway.signOut()
  try await client.finish(fixtureSession())
  await #expect(throws: GatewayError.unauthorized) { try await request.value }
  #expect(await storage.load() == nil)
}
@Test func gatewayDeclinesRedirects() {
  let url = URL(string: "https://example.invalid")!
  let response = HTTPURLResponse(
    url: url, statusCode: 307, httpVersion: nil, headerFields: ["Location": "https://other.invalid"]
  )!
  let session = URLSession(configuration: .ephemeral)
  defer { session.invalidateAndCancel() }
  GatewayRedirectPolicy().urlSession(
    session, task: session.dataTask(with: url),
    willPerformHTTPRedirection: response,
    newRequest: URLRequest(url: URL(string: "https://other.invalid")!)
  ) { redirected in
    #expect(redirected == nil)
  }
}

private actor ImmediateAuthClient: GatewayHTTPClient {
  private(set) var count = 0
  func send(_ request: URLRequest) async throws -> (Data, Int) {
    count += 1
    return (try JSONEncoder().encode(fixtureSession()), 200)
  }
}
private actor PausedSaveStorage: SessionStorage {
  private var session: AuthSession?
  private var saveStarted = false
  private var started: CheckedContinuation<Void, Never>?
  private var saved: CheckedContinuation<Void, Never>?
  func save(_ session: AuthSession) async {
    if !saveStarted {
      saveStarted = true
      await withCheckedContinuation { continuation in
        saved = continuation
        started?.resume()
        started = nil
      }
    }
    self.session = session
  }
  func load() -> AuthSession? { session }
  func clear() { session = nil }
  func waitUntilSaveStarted() async {
    if saveStarted { return }
    await withCheckedContinuation { started = $0 }
  }
  func finishSave() {
    saved?.resume()
    saved = nil
  }
}
@Test(.timeLimit(.minutes(1))) func signOutOrdersClearAfterSuspendedSessionSave() async throws {
  let storage = PausedSaveStorage()
  let client = ImmediateAuthClient()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let login = Task {
    try await gateway.signIn(email: "fixture@example.invalid", password: "fixture")
  }
  await storage.waitUntilSaveStarted()
  let logout = Task { try await gateway.signOut() }
  // The save stays suspended while signOut queues its clear behind it.
  for _ in 0..<100 { await Task.yield() }
  await storage.finishSave()
  await #expect(throws: GatewayError.unauthorized) { try await login.value }
  try await logout.value
  #expect(await storage.load() == nil)
  await #expect(throws: GatewayError.unauthorized) { try await gateway.refresh() }
}
@Test(.timeLimit(.minutes(1))) func staleSaveCompletionDoesNotClearNewerLogin() async throws {
  let storage = PausedSaveStorage()
  let client = ImmediateAuthClient()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let first = Task { try await gateway.signIn(email: "first@example.invalid", password: "fixture") }
  await storage.waitUntilSaveStarted()
  let logout = Task { try await gateway.signOut() }
  for _ in 0..<100 { await Task.yield() }
  let newer = Task { try await gateway.signIn(email: "newer@example.invalid", password: "fixture") }
  for _ in 0..<100 { await Task.yield() }
  await storage.finishSave()
  await #expect(throws: GatewayError.unauthorized) { try await first.value }
  try await logout.value
  let newSession = try await newer.value
  #expect(await storage.load() == newSession)
}
private actor PausedLoadStorage: SessionStorage {
  private var session: AuthSession? = fixtureSession()
  private var loadStarted = false
  private var started: CheckedContinuation<Void, Never>?
  private var loaded: CheckedContinuation<Void, Never>?
  func save(_ session: AuthSession) { self.session = session }
  func load() async -> AuthSession? {
    let snapshot = session
    if !loadStarted {
      loadStarted = true
      await withCheckedContinuation { continuation in
        loaded = continuation
        started?.resume()
        started = nil
      }
    }
    return snapshot
  }
  func clear() { session = nil }
  func waitUntilLoadStarted() async {
    if loadStarted { return }
    await withCheckedContinuation { started = $0 }
  }
  func finishLoad() {
    loaded?.resume()
    loaded = nil
  }
}
@Test(.timeLimit(.minutes(1))) func suspendedTokenLoadCannotStartRequestAfterSignOut() async throws
{
  let storage = PausedLoadStorage()
  let client = ImmediateAuthClient()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let pull = Task {
    try await gateway.pull(ownerID: "018f0000-0000-7000-8000-000000000001", after: 0, limit: 100)
  }
  await storage.waitUntilLoadStarted()
  try await gateway.signOut()
  await storage.finishLoad()
  await #expect(throws: GatewayError.unauthorized) { try await pull.value }
  #expect(await client.count == 0)
}
