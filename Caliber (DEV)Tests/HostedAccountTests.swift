import CaliberIntegrations
import Foundation
import Testing

@testable import Caliber__DEV_

private func accountTestDefaults(consented: Bool = true) -> UserDefaults {
  let name = "Caliber.Account.Tests." + UUID().uuidString
  let defaults = UserDefaults(suiteName: name)!
  defaults.removePersistentDomain(forName: name)
  if consented {
    defaults.set(AccountAccessConsent.version, forKey: "account.access.consent.version")
  }
  return defaults
}
private actor RetryAccountGateway: AccountGateway {
  private var failures = 1
  private(set) var restoreCount = 0
  private(set) var signOutCount = 0
  private let signInError: GatewayError
  init(signInError: GatewayError = .unauthorized) { self.signInError = signInError }
  func restoredSession() throws -> AuthSession? {
    restoreCount += 1
    if failures > 0 {
      failures -= 1
      throw GatewayError.unavailable
    }
    return AuthSession(
      accessToken: "fictional", refreshToken: "fictional",
      subject: "00000000-0000-4000-8000-000000000001", expiresAt: .now.addingTimeInterval(3600))
  }
  func signIn(email: String, password: String) throws -> AuthSession {
    throw signInError
  }
  func confirmAccountAccess() {}
  func requestPasswordRecovery(email: String) throws { throw signInError }
  func resetPassword(email: String, code: String, newPassword: String) throws -> PasswordResetResult
  { throw signInError }
  func deleteAccount(password: String) throws -> AccountDeletionResult { throw signInError }
  func signOutOnThisDevice() -> DeviceSignOutResult {
    signOutCount += 1
    return .localOnly
  }
}

@MainActor @Test func failedAccountRestoreCanBeRetriedWithoutRestart() async throws {
  let project = try HostedProject(
    projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!, region: "us-east-1",
    gatewayDeployed: true)
  let gateway = RetryAccountGateway()
  let model = HostedAccountModel(
    project: project, gateway: gateway, defaults: accountTestDefaults())
  await model.restore()
  #expect(model.restoreFailed && !model.isSignedIn && !model.isBusy)
  await model.restore()
  #expect(!model.restoreFailed && model.isSignedIn && !model.isBusy)
  await model.restore()
  #expect(await gateway.restoreCount == 2)
}

@MainActor @Test func failedAccountRestoreCanClearSessionOffline() async throws {
  let project = try HostedProject(
    projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!, region: "us-east-1",
    gatewayDeployed: true)
  let gateway = RetryAccountGateway()
  let model = HostedAccountModel(
    project: project, gateway: gateway, defaults: accountTestDefaults())
  await model.restore()
  await model.signOut()
  #expect(await gateway.signOutCount == 1)
  #expect(!model.restoreFailed && !model.isSignedIn)
  #expect(model.message?.contains("could not confirm sign-out") == true)
}

@MainActor @Test func pendingDeploymentCannotContactAccountGateway() async throws {
  let project = try HostedProject(
    projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!, region: "us-east-1",
    gatewayDeployed: false)
  let gateway = RetryAccountGateway()
  let model = HostedAccountModel(
    project: project, gateway: gateway, defaults: accountTestDefaults())
  await model.restore()
  await model.signIn(email: "fictional@example.invalid", password: "fixture")
  #expect(await gateway.restoreCount == 0)
  #expect(!model.isAvailable && !model.isSignedIn)
}

@MainActor @Test func rateLimitedAccountShowsWaitMessageAndLeavesLocalLogsUsable() async throws {
  let project = try HostedProject(
    projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!, region: "us-east-1",
    gatewayDeployed: true)
  let model = HostedAccountModel(
    project: project, gateway: RetryAccountGateway(signInError: .rateLimited),
    defaults: accountTestDefaults())
  await model.signIn(email: "fictional@example.invalid", password: "fixture")
  #expect(!model.isSignedIn && !model.isBusy)
  #expect(model.message == "Too many sign-in attempts. Wait a few minutes and try again.")
}

@MainActor @Test func missingConsentPreventsRestoreSignInAndRecovery() async throws {
  let project = try HostedProject(
    projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!, region: "us-east-1",
    gatewayDeployed: true)
  let gateway = RetryAccountGateway()
  let defaults = accountTestDefaults(consented: false)
  let model = HostedAccountModel(project: project, gateway: gateway, defaults: defaults)
  await model.restore()
  await model.signIn(email: "fixture@example.invalid", password: "fixture")
  await model.requestPasswordRecovery(email: "fixture@example.invalid")
  #expect(await gateway.restoreCount == 0)
  #expect(model.message == nil && !model.hasAccountConsent && !model.isSignedIn)
  model.acceptAccountConsent()
  #expect(model.hasAccountConsent)
  #expect(defaults.object(forKey: "account.access.consent.date") is Date)
  await model.stopAccountServices()
  #expect(!model.hasAccountConsent && !model.isSignedIn)
  #expect(defaults.string(forKey: "account.access.consent.version") == nil)
}
@MainActor @Test func accountRecoveryFailureLeavesSessionAndLocalWorkAlone() async throws {
  let project = try HostedProject(
    projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!, region: "us-east-1",
    gatewayDeployed: true)
  let gateway = RetryAccountGateway(signInError: .rateLimited)
  let model = HostedAccountModel(
    project: project, gateway: gateway, defaults: accountTestDefaults())
  await model.requestPasswordRecovery(email: "fixture@example.invalid")
  #expect(!model.recoveryRequested && !model.isSignedIn && !model.isBusy)
  #expect(model.message?.contains("Wait a few minutes") == true)
  await model.resetPassword(
    email: "fixture@example.invalid", code: "123456", newPassword: "fictional-password")
  #expect(!model.isSignedIn && !model.isBusy)
  #expect(await gateway.signOutCount == 0)
}
