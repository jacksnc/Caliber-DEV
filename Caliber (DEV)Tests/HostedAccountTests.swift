import CaliberIntegrations
import Foundation
import Testing

@testable import Caliber__DEV_

private actor RetryAccountGateway: AccountGateway {
  private var failures = 1
  private(set) var restoreCount = 0
  private(set) var signOutCount = 0
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
    throw GatewayError.unauthorized
  }
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
  let model = HostedAccountModel(project: project, gateway: gateway)
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
  let model = HostedAccountModel(project: project, gateway: gateway)
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
  let model = HostedAccountModel(project: project, gateway: gateway)
  await model.restore()
  await model.signIn(email: "fictional@example.invalid", password: "fixture")
  #expect(await gateway.restoreCount == 0)
  #expect(!model.isAvailable && !model.isSignedIn)
}
