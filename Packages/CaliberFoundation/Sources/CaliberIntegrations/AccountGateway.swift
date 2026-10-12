import Foundation

/// Version only covers hosted account access. Personal backup needs separate consent.
public enum AccountAccessConsent {
  public static let version = "account-access-v1"
}
public struct PasswordResetResult: Decodable, Sendable, Equatable {
  public let passwordUpdated: Bool
  public let sessionsRevoked: Bool
  public init(passwordUpdated: Bool, sessionsRevoked: Bool) {
    self.passwordUpdated = passwordUpdated
    self.sessionsRevoked = sessionsRevoked
  }
}
public enum AccountDeletionResult: Sendable, Equatable {
  case deleted, sessionRemovalPending
}
/// Account transport is independent of the app's main-thread UI and personal logs.
public protocol AccountGateway: Sendable {
  func restoredSession() async throws -> AuthSession?
  func signIn(email: String, password: String) async throws -> AuthSession
  func signOutOnThisDevice() async throws -> DeviceSignOutResult
  func confirmAccountAccess() async throws
  func requestPasswordRecovery(email: String) async throws
  func resetPassword(email: String, code: String, newPassword: String) async throws
    -> PasswordResetResult
  func deleteAccount(password: String) async throws -> AccountDeletionResult
}

extension CloudGateway: AccountGateway {}
