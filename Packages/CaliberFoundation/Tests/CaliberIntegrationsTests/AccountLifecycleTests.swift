import Foundation
import Testing

@testable import CaliberIntegrations

private actor LifecycleStorage: SessionStorage {
  var session: AuthSession?
  let failsClear: Bool
  init(failsClear: Bool = false) {
    self.failsClear = failsClear
    session = AuthSession(
      accessToken: "fixture-access", refreshToken: "fixture-refresh",
      subject: "00000000-0000-4000-8000-000000000001", expiresAt: .now.addingTimeInterval(3600))
  }
  func save(_ value: AuthSession) { session = value }
  func load() -> AuthSession? { session }
  func clear() throws {
    if failsClear { throw GatewayError.keychain }
    session = nil
  }
}
private actor LifecycleHTTP: GatewayHTTPClient {
  let status: Int
  let body: String
  var requests: [URLRequest] = []
  init(_ body: String, status: Int = 200) {
    self.body = body
    self.status = status
  }
  func send(_ request: URLRequest) -> (Data, Int) {
    requests.append(request)
    return (Data(body.utf8), status)
  }
}
private func lifecycleGateway(_ http: LifecycleHTTP, storage: LifecycleStorage) throws
  -> CloudGateway
{
  CloudGateway(
    configuration: try CloudConfiguration(endpoint: URL(string: "https://example.invalid/api")!),
    http: http, vault: storage)
}
@Test func recoveryNeverSavesOrClearsAnExistingSession() async throws {
  let storage = LifecycleStorage()
  let before = await storage.load()
  let requested = LifecycleHTTP("{\"recoveryRequested\":true}", status: 202)
  try await lifecycleGateway(requested, storage: storage).requestPasswordRecovery(
    email: "fixture@example.invalid")
  let reset = LifecycleHTTP("{\"passwordUpdated\":true,\"sessionsRevoked\":true}")
  let result = try await lifecycleGateway(reset, storage: storage).resetPassword(
    email: "fixture@example.invalid", code: "123456", newPassword: "fixture-password")
  #expect(result.passwordUpdated && result.sessionsRevoked)
  #expect(await storage.load() == before)
  for client in [requested, reset] {
    let request = try #require(await client.requests.first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.value(forHTTPHeaderField: "apikey") == nil)
  }
}
@Test func deletionClearsOnlyAfterServerConfirmationAndSendsNoTargetID() async throws {
  let storage = LifecycleStorage()
  let http = LifecycleHTTP("{\"accountDeleted\":true}")
  #expect(
    try await lifecycleGateway(http, storage: storage).deleteAccount(password: "fixture-password")
      == .deleted)
  #expect(await storage.load() == nil)
  let request = try #require(await http.requests.first)
  let body = try #require(request.httpBody)
  let fields = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
  #expect(fields == ["password": "fixture-password", "confirmation": "DELETE"])
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access")
}
@Test(arguments: [401, 409, 500]) func deletionFailureKeepsTheSavedSession(status: Int) async throws
{
  let storage = LifecycleStorage()
  let before = await storage.load()
  let http = LifecycleHTTP("private provider details", status: status)
  await #expect(throws: (any Error).self) {
    try await lifecycleGateway(http, storage: storage).deleteAccount(password: "wrong-fixture")
  }
  #expect(await storage.load() == before)
}
@Test func deletionReportsConfirmedRemoteDeletionEvenIfKeychainClearingFails() async throws {
  let storage = LifecycleStorage(failsClear: true)
  let http = LifecycleHTTP("{\"accountDeleted\":true}")
  let gateway = try lifecycleGateway(http, storage: storage)
  #expect(try await gateway.deleteAccount(password: "fixture") == .sessionRemovalPending)
  #expect(try await gateway.restoredSession() == nil)
}
@Test func malformedDeletionReplyCannotClearSession() async throws {
  let storage = LifecycleStorage()
  let http = LifecycleHTTP("{\"accountDeleted\":false}")
  await #expect(throws: GatewayError.invalidResponse) {
    try await lifecycleGateway(http, storage: storage).deleteAccount(password: "fixture")
  }
  #expect(await storage.load() != nil)
}
@Test func restoredConsentRequiresExactVersionAndNoCallerSubject() async throws {
  let storage = LifecycleStorage()
  let http = LifecycleHTTP("{\"accepted\":true,\"version\":\"account-access-v1\"}")
  try await lifecycleGateway(http, storage: storage).confirmAccountAccess()
  let body = try #require(await http.requests.first?.httpBody)
  #expect(
    try JSONSerialization.jsonObject(with: body) as? [String: String] == [
      "version": AccountAccessConsent.version
    ])
}
