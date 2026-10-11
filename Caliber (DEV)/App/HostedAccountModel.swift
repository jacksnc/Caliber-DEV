import CaliberIntegrations
import Combine
import Foundation

/// Account access is independent of the personal diary. Signing in does not upload logs.
@MainActor
final class HostedAccountModel: ObservableObject {
  @Published private(set) var isBusy = false
  @Published private(set) var isSignedIn = false
  @Published private(set) var restoreFailed = false
  @Published private(set) var message: String?
  let project: HostedProject?
  let isAvailable: Bool
  private let gateway: any AccountGateway
  private var didRestore = false

  init(project: HostedProject?, gateway: any AccountGateway) {
    self.project = project
    self.gateway = gateway
    isAvailable = project?.gatewayDeployed == true
  }
  static func configured(testing: Bool) -> HostedAccountModel {
    let project = Bundle.main.url(forResource: "CloudDeployment", withExtension: "json")
      .flatMap { try? Data(contentsOf: $0) }
      .flatMap { try? JSONDecoder().decode(HostedProject.self, from: $0) }
    #if DEBUG
      if testing && ProcessInfo.processInfo.arguments.contains("--account-ui-testing") {
        let fixture = try? HostedProject(
          projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!,
          region: "us-east-1", gatewayDeployed: true)
        return HostedAccountModel(project: fixture, gateway: FixtureAccountGateway())
      }
    #endif
    return HostedAccountModel(
      project: project,
      gateway: CloudGateway(
        configuration: try? project?.configuration(),
        vault: SessionVault(service: project?.sessionService ?? "Caliber.Foundation.Unconfigured")))
  }
  func restore() async {
    guard isAvailable, !didRestore, !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      isSignedIn = try await gateway.restoredSession() != nil
      didRestore = true
      restoreFailed = false
      message = nil
    } catch {
      // A failed check must leave the saved session available for retry or removal.
      restoreFailed = true
      message = "Your account could not be checked. Your local logs are still available."
    }
  }
  func signIn(email: String, password: String) async {
    guard isAvailable, !isBusy else { return }
    isBusy = true
    message = nil
    defer { isBusy = false }
    do {
      _ = try await gateway.signIn(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
      isSignedIn = true
      didRestore = true
      restoreFailed = false
      message = "Signed in. Your logs remain on this device; cloud backup is not active yet."
    } catch {
      message =
        error as? GatewayError == .unauthorized
        ? "Sign-in was not accepted. Check your email and password."
        : "Could not sign in. Check your connection and try again."
    }
  }
  func signOut() async {
    guard !isBusy else { return }
    isBusy = true
    message = nil
    defer { isBusy = false }
    do {
      let result = try await gateway.signOutOnThisDevice()
      isSignedIn = false
      didRestore = true
      restoreFailed = false
      message =
        result == .remoteRevoked
        ? "Signed out on this device."
        : "Signed out locally. The server could not confirm sign-out. Your session there may remain valid until it expires."
    } catch {
      message = "Could not remove the saved session. Unlock this device and try signing out again."
    }
  }
}

#if DEBUG
  /// Only isolated UI launches can use this fictional account. It never sends network requests.
  private actor FixtureAccountGateway: AccountGateway {
    private var session: AuthSession?
    func restoredSession() -> AuthSession? { session }
    func signIn(email: String, password: String) throws -> AuthSession {
      guard email == "fixture@example.invalid", password == "fixture-password" else {
        throw GatewayError.unauthorized
      }
      let next = AuthSession(
        accessToken: "fixture-access", refreshToken: "fixture-refresh",
        subject: "00000000-0000-4000-8000-000000000001", expiresAt: .now.addingTimeInterval(3600))
      session = next
      return next
    }
    func signOutOnThisDevice() -> DeviceSignOutResult {
      session = nil
      return .remoteRevoked
    }
  }
#endif
