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
  @Published private(set) var hasAccountConsent: Bool
  @Published private(set) var recoveryRequested = false
  @Published private(set) var sessionRemovalPending = false
  let project: HostedProject?
  let isAvailable: Bool
  private let gateway: any AccountGateway
  private var didRestore = false
  private let defaults: UserDefaults
  private static let consentKey = "account.access.consent.version"
  private static let consentDateKey = "account.access.consent.date"

  init(project: HostedProject?, gateway: any AccountGateway, defaults: UserDefaults = .standard) {
    self.defaults = defaults
    hasAccountConsent = defaults.string(forKey: Self.consentKey) == AccountAccessConsent.version
    self.project = project
    self.gateway = gateway
    isAvailable = project?.gatewayDeployed == true
  }
  static func configured(testing: Bool, defaults: UserDefaults) -> HostedAccountModel {
    let project = Bundle.main.url(forResource: "CloudDeployment", withExtension: "json")
      .flatMap { try? Data(contentsOf: $0) }
      .flatMap { try? JSONDecoder().decode(HostedProject.self, from: $0) }
    #if DEBUG
      if testing && ProcessInfo.processInfo.arguments.contains("--account-ui-testing") {
        let fixture = try? HostedProject(
          projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!,
          region: "us-east-1", gatewayDeployed: true)
        return HostedAccountModel(
          project: fixture, gateway: FixtureAccountGateway(), defaults: defaults)
      }
    #endif
    return HostedAccountModel(
      project: project,
      gateway: CloudGateway(
        configuration: try? project?.configuration(),
        vault: SessionVault(service: project?.sessionService ?? "Caliber.Foundation.Unconfigured")),
      defaults: defaults)
  }
  /// FUEL-10 photo estimates use the signed-in session; the provider key stays on the server.
  var canEstimatePhotos: Bool { isAvailable && isSignedIn && gateway is any FoodPhotoGateway }

  func estimateFoodPhoto(jpegBase64: String) async throws -> FoodPhotoProposal {
    guard isSignedIn, let photos = gateway as? any FoodPhotoGateway else {
      throw GatewayError.unauthorized
    }
    return try await photos.proposeFoodItems(jpegBase64: jpegBase64)
  }

  func acceptAccountConsent() {
    guard isAvailable, !isBusy else { return }
    defaults.set(AccountAccessConsent.version, forKey: Self.consentKey)
    defaults.set(Date(), forKey: Self.consentDateKey)
    hasAccountConsent = true
    message = nil
  }
  func stopAccountServices() async {
    guard !isBusy else { return }
    defaults.removeObject(forKey: Self.consentKey)
    defaults.removeObject(forKey: Self.consentDateKey)
    hasAccountConsent = false
    recoveryRequested = false
    isSignedIn = false
    sessionRemovalPending = true
    await signOut()
  }
  func restore() async {
    guard isAvailable, hasAccountConsent, !didRestore, !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      let restored = try await gateway.restoredSession()
      if restored != nil { try await gateway.confirmAccountAccess() }
      isSignedIn = restored != nil
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
    guard isAvailable, hasAccountConsent, !isBusy else { return }
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
      switch error as? GatewayError {
      case .unauthorized:
        message = "Sign-in was not accepted. Check your email and password."
      case .rateLimited:
        message = String(localized: "Too many sign-in attempts. Wait a few minutes and try again.")
      default:
        message = "Could not sign in. Check your connection and try again."
      }
    }
  }
  func requestPasswordRecovery(email: String) async {
    guard isAvailable, hasAccountConsent, !isBusy, !isSignedIn else { return }
    isBusy = true
    message = nil
    defer { isBusy = false }
    do {
      try await gateway.requestPasswordRecovery(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines))
      recoveryRequested = true
      message = String(
        localized:
          "If this email has an account, a recovery code has been requested. Check your inbox and spam folder."
      )
    } catch {
      message =
        error as? GatewayError == .rateLimited
        ? String(localized: "Too many recovery attempts. Wait a few minutes and try again.")
        : String(localized: "Could not request recovery. Check your connection and try again.")
    }
  }
  func resetPassword(email: String, code: String, newPassword: String) async {
    guard isAvailable, hasAccountConsent, !isBusy, !isSignedIn else { return }
    isBusy = true
    message = nil
    defer { isBusy = false }
    do {
      let result = try await gateway.resetPassword(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines), code: code,
        newPassword: newPassword)
      recoveryRequested = false
      message =
        result.sessionsRevoked
        ? String(localized: "Password changed. Sign in with your new password.")
        : String(
          localized:
            "Password changed. Session revocation could not be confirmed; earlier sessions may remain active. Sign in with your new password."
        )
    } catch {
      switch error as? GatewayError {
      case .unauthorized:
        message = String(
          localized: "The recovery code was not accepted. Check it or request a new code.")
      case .rateLimited:
        message = String(localized: "Too many recovery attempts. Wait a few minutes and try again.")
      default:
        message = String(
          localized:
            "Could not confirm the reset. Try signing in with the new password, or request a new recovery code."
        )
      }
    }
  }
  func deleteAccount(password: String) async {
    guard isAvailable, hasAccountConsent, isSignedIn, !isBusy else { return }
    isBusy = true
    message = nil
    defer { isBusy = false }
    do {
      let result = try await gateway.deleteAccount(password: password)
      isSignedIn = false
      didRestore = true
      restoreFailed = false
      defaults.removeObject(forKey: Self.consentKey)
      defaults.removeObject(forKey: Self.consentDateKey)
      hasAccountConsent = false
      sessionRemovalPending = result == .sessionRemovalPending
      message =
        sessionRemovalPending
        ? String(
          localized:
            "Hosted account deleted. Unlock this device and remove the saved session. Your local logs and photos are still here."
        )
        : String(localized: "Hosted account deleted. Your local logs and photos are still here.")
    } catch {
      message =
        error as? GatewayError == .unauthorized
        ? String(
          localized: "Deletion was not accepted. Check your current password or sign in again.")
        : String(
          localized:
            "Deletion could not be confirmed. Your local logs are safe. Try again when connected.")
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
      sessionRemovalPending = false
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
    func confirmAccountAccess() throws {
      guard session != nil else { throw GatewayError.unauthorized }
    }
    func requestPasswordRecovery(email: String) {}
    func resetPassword(email: String, code: String, newPassword: String) throws
      -> PasswordResetResult
    {
      guard code == "123456" else { throw GatewayError.unauthorized }
      return PasswordResetResult(passwordUpdated: true, sessionsRevoked: true)
    }
    func deleteAccount(password: String) throws -> AccountDeletionResult {
      guard session != nil, password == "fixture-password" else { throw GatewayError.unauthorized }
      session = nil
      return .deleted
    }
    func signOutOnThisDevice() -> DeviceSignOutResult {
      session = nil
      return .remoteRevoked
    }
  }
#endif
