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

@Test func throttledResponseHasSafeTypedErrorAndCannotSaveASession() async throws {
  let storage = MemorySessionStorage()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: FailureClient(status: 429), vault: storage)
  await #expect(throws: GatewayError.rateLimited) {
    try await gateway.signIn(email: "fixture@example.invalid", password: "fixture")
  }
  #expect(await storage.load() == nil)
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

private func namedSession(_ name: String, expiresAt: Date = Date().addingTimeInterval(3600))
  -> AuthSession
{
  AuthSession(
    accessToken: name + "-access", refreshToken: name + "-refresh",
    subject: "00000000-0000-4000-8000-000000000001", expiresAt: expiresAt)
}
private actor SessionLifecycleClient: GatewayHTTPClient {
  let result: AuthSession
  let logoutStatus: Int
  private(set) var requests: [URLRequest] = []
  init(result: AuthSession = namedSession("new"), logoutStatus: Int = 200) {
    self.result = result
    self.logoutStatus = logoutStatus
  }
  func send(_ request: URLRequest) throws -> (Data, Int) {
    requests.append(request)
    if request.url?.path.hasSuffix("auth/sign-out") == true {
      return (Data("{\"signedOut\":true}".utf8), logoutStatus)
    }
    return (try JSONEncoder().encode(result), 200)
  }
}
@Test func absentAndCurrentSessionsRestoreWithoutNetwork() async throws {
  let client = SessionLifecycleClient()
  let empty = CloudGateway(configuration: nil, http: client, vault: MemorySessionStorage())
  #expect(try await empty.restoredSession() == nil)
  let saved = namedSession("saved")
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: MemorySessionStorage(saved))
  #expect(try await gateway.restoredSession() == saved)
  #expect(await client.requests.isEmpty)
}
@Test func restoringExpiredSessionRefreshesAndPersistsTheSameIdentity() async throws {
  let expired = namedSession("expired", expiresAt: Date().addingTimeInterval(-60))
  let next = namedSession("refreshed")
  let client = SessionLifecycleClient(result: next)
  let storage = MemorySessionStorage(expired)
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  #expect(try await gateway.restoredSession() == next)
  #expect(await storage.load() == next)
  let requests = await client.requests
  #expect(requests.count == 1)
  let request = try #require(requests.first)
  #expect(request.url?.path == "/api/auth/refresh")
  let requestBody = try #require(request.httpBody)
  let body = try #require(try JSONSerialization.jsonObject(with: requestBody) as? [String: String])
  #expect(body == ["refreshToken": expired.refreshToken])
}
@Test func deviceSignOutClearsLocallyAndRevokesOnlyCapturedSession() async throws {
  let saved = namedSession("saved")
  let client = SessionLifecycleClient()
  let storage = MemorySessionStorage(saved)
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  #expect(try await gateway.signOutOnThisDevice() == .remoteRevoked)
  #expect(await storage.load() == nil)
  #expect(try await gateway.restoredSession() == nil)
  let request = try #require(await client.requests.first)
  #expect(request.url?.path == "/api/auth/sign-out")
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + saved.accessToken)
  let requestBody = try #require(request.httpBody)
  let body = try #require(try JSONSerialization.jsonObject(with: requestBody) as? [String: String])
  #expect(body.isEmpty)
}
@Test(arguments: [401, 500]) func failedRemoteRevocationStillClearsDevice(status: Int) async throws
{
  let storage = MemorySessionStorage(namedSession("saved"))
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: SessionLifecycleClient(logoutStatus: status), vault: storage)
  #expect(try await gateway.signOutOnThisDevice() == .localOnly)
  #expect(await storage.load() == nil)
  #expect(try await gateway.restoredSession() == nil)
}
private struct OfflineClient: GatewayHTTPClient {
  func send(_ request: URLRequest) throws -> (Data, Int) { throw URLError(.notConnectedToInternet) }
}
@Test func offlineSignOutAndUnconfiguredSignOutKeepLocalClearingAvailable() async throws {
  for configuration in [
    nil, try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
  ] {
    let storage = MemorySessionStorage(namedSession("saved"))
    let gateway = CloudGateway(configuration: configuration, http: OfflineClient(), vault: storage)
    #expect(try await gateway.signOutOnThisDevice() == .localOnly)
    #expect(await storage.load() == nil)
  }
}
private actor DelayedLogoutClient: GatewayHTTPClient {
  private var response: CheckedContinuation<(Data, Int), Never>?
  private var started: CheckedContinuation<Void, Never>?
  private var logoutStarted = false
  private(set) var revokedAuthorization: String?
  func send(_ request: URLRequest) async throws -> (Data, Int) {
    if request.url?.path.hasSuffix("auth/sign-out") == true {
      revokedAuthorization = request.value(forHTTPHeaderField: "Authorization")
      logoutStarted = true
      return await withCheckedContinuation { continuation in
        response = continuation
        started?.resume()
        started = nil
      }
    }
    return (try JSONEncoder().encode(namedSession("newer")), 200)
  }
  func waitForLogout() async {
    if logoutStarted { return }
    await withCheckedContinuation { started = $0 }
  }
  func finishLogout() {
    response?.resume(returning: (Data("{\"signedOut\":true}".utf8), 200))
    response = nil
  }
}
@Test(.timeLimit(.minutes(1))) func remoteLogoutCompletionDoesNotClearOrRevokeNewerLogin()
  async throws
{
  let old = namedSession("old")
  let storage = MemorySessionStorage(old)
  let client = DelayedLogoutClient()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let logout = Task { try await gateway.signOutOnThisDevice() }
  await client.waitForLogout()
  #expect(await storage.load() == nil)
  let newer = try await gateway.signIn(email: "newer@example.invalid", password: "fixture")
  await client.finishLogout()
  #expect(try await logout.value == .remoteRevoked)
  #expect(await storage.load() == newer)
  #expect(try await gateway.restoredSession() == newer)
  #expect(await client.revokedAuthorization == "Bearer " + old.accessToken)
}
@Test(.timeLimit(.minutes(1))) func captureAndClearAreOrderedBeforeNewerSessionSave() async throws {
  let storage = PausedLoadStorage()
  let client = SessionLifecycleClient(result: namedSession("newer"))
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let logout = Task { try await gateway.signOutOnThisDevice() }
  await storage.waitUntilLoadStarted()
  let login = Task { try await gateway.signIn(email: "newer@example.invalid", password: "fixture") }
  for _ in 0..<100 { await Task.yield() }
  await storage.finishLoad()
  #expect(try await logout.value == .remoteRevoked)
  let newer = try await login.value
  #expect(await storage.load() == newer)
  let logoutRequest = try #require(
    await client.requests.first { $0.url?.path.hasSuffix("auth/sign-out") == true })
  #expect(logoutRequest.value(forHTTPHeaderField: "Authorization") == "Bearer fictional-access")
}
private struct UnclearableStorage: SessionStorage {
  func save(_ session: AuthSession) throws {}
  func load() -> AuthSession? { namedSession("saved") }
  func clear() throws { throw GatewayError.keychain }
}
@Test func keychainClearFailureIsNotReportedAsSuccessfulSignOut() async throws {
  let client = SessionLifecycleClient()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: UnclearableStorage())
  await #expect(throws: GatewayError.keychain) { try await gateway.signOutOnThisDevice() }
  #expect(await client.requests.isEmpty)
}
@Test(.timeLimit(.minutes(1))) func signOutInvalidatesRestorationPausedOnStorage() async throws {
  let storage = PausedLoadStorage()
  let client = SessionLifecycleClient()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let restore = Task { try await gateway.restoredSession() }
  await storage.waitUntilLoadStarted()
  try await gateway.signOut()
  await storage.finishLoad()
  await #expect(throws: GatewayError.unauthorized) { try await restore.value }
  #expect(await client.requests.isEmpty)
}

@Test(arguments: [
  "", "us-east-1\r\nx-api-key: injected", "us-east-1\n", "us-east-1\r", "US-EAST-1", "us east 1",
  "us-east", "arbitrary",
])
func invocationRegionRejectsMalformedOrHeaderLikeValues(_ region: String) {
  #expect(throws: GatewayError.insecureEndpoint) {
    try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!, region: region)
  }
}
@Test func requestedInvocationRegionIsSentWithoutAnyClientAPIKey() async throws {
  let client = SessionLifecycleClient()
  let storage = MemorySessionStorage()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(
      endpoint: URL(string: "https://example.invalid/api")!, region: "us-east-1"),
    http: client, vault: storage)
  _ = try await gateway.signIn(email: "fixture@example.invalid", password: "fixture")
  _ = try await gateway.refresh()
  _ = try await gateway.signOutOnThisDevice()
  let requests = await client.requests
  #expect(requests.count == 3)
  for request in requests {
    #expect(request.value(forHTTPHeaderField: "x-region") == "us-east-1")
    #expect(request.value(forHTTPHeaderField: "apikey") == nil)
    #expect(request.value(forHTTPHeaderField: "x-api-key") == nil)
  }
}
@Test func unspecifiedInvocationRegionDoesNotAddAnEmptyHeader() async throws {
  let client = SessionLifecycleClient()
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: MemorySessionStorage())
  _ = try await gateway.signIn(email: "fixture@example.invalid", password: "fixture")
  #expect(await client.requests.first?.value(forHTTPHeaderField: "x-region") == nil)
}

@Test(.timeLimit(.minutes(1))) func deviceSignOutCapturesSessionOnlyAfterEarlierSaveFinishes()
  async throws
{
  let storage = PausedSaveStorage()
  let saved = namedSession("pending")
  let client = SessionLifecycleClient(result: saved)
  let gateway = CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: client, vault: storage)
  let login = Task {
    try await gateway.signIn(email: "fixture@example.invalid", password: "fixture")
  }
  await storage.waitUntilSaveStarted()
  let logout = Task { try await gateway.signOutOnThisDevice() }
  for _ in 0..<100 { await Task.yield() }
  await storage.finishSave()
  await #expect(throws: GatewayError.unauthorized) { try await login.value }
  #expect(try await logout.value == .remoteRevoked)
  #expect(await storage.load() == nil)
  let request = try #require(
    await client.requests.first { $0.url?.path.hasSuffix("auth/sign-out") == true })
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + saved.accessToken)
}

private struct RecordingPhotoClient: GatewayHTTPClient {
  let reply: String
  let seen = Recorder()
  final class Recorder: @unchecked Sendable {
    var request: URLRequest?
  }
  func send(_ request: URLRequest) async throws -> (Data, Int) {
    seen.request = request
    return (Data(reply.utf8), 200)
  }
}
@Test func photoEstimateSendsOnlyTheImageWithTheSessionAndChecksTheReply() async throws {
  let configuration = try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!)
  let client = RecordingPhotoClient(
    reply:
      #"{"items":[{"name":"banana","grams":118,"confidence":"high"}],"model":"m","promptVersion":"v"}"#
  )
  let gateway = CloudGateway(
    configuration: configuration, http: client, vault: MemorySessionStorage(fixtureSession()))
  let proposal = try await gateway.proposeFoodItems(jpegBase64: "/9j/AAAA")
  #expect(proposal.items == [FoodPhotoItem(name: "banana", grams: 118, confidence: "high")])
  let request = try #require(client.seen.request)
  #expect(request.url?.path == "/api/ai/food-photo")
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fictional-access")
  #expect(request.timeoutInterval == 60)
  let body = try #require(request.httpBody)
  #expect(
    try JSONSerialization.jsonObject(with: body) as? [String: String] == ["image": "/9j/AAAA"])

  let invented = CloudGateway(
    configuration: configuration,
    http: RecordingPhotoClient(
      reply:
        #"{"items":[{"name":"x","grams":0,"confidence":"high"}],"model":"m","promptVersion":"v"}"#
    ),
    vault: MemorySessionStorage(fixtureSession()))
  await #expect(throws: GatewayError.invalidResponse) {
    try await invented.proposeFoodItems(jpegBase64: "/9j/AAAA")
  }
  let signedOut = CloudGateway(
    configuration: configuration, http: client, vault: MemorySessionStorage())
  await #expect(throws: GatewayError.unauthorized) {
    try await signedOut.proposeFoodItems(jpegBase64: "/9j/AAAA")
  }
}
