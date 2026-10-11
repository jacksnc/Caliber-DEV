import Foundation

/// Account transport is independent of the app's main-thread UI and personal logs.
public protocol AccountGateway: Sendable {
  func restoredSession() async throws -> AuthSession?
  func signIn(email: String, password: String) async throws -> AuthSession
  func signOutOnThisDevice() async throws -> DeviceSignOutResult
}

extension CloudGateway: AccountGateway {}
