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

/// One food a vision model saw in a meal photo (FUEL-10). The gateway returns names, weights and
/// confidence only; nutrition always comes from the app's food database.
public struct FoodPhotoItem: Codable, Sendable, Equatable {
  public let name: String
  public let grams: Double
  public let confidence: String
  public init(name: String, grams: Double, confidence: String) {
    self.name = name
    self.grams = grams
    self.confidence = confidence
  }
}
public struct FoodPhotoProposal: Codable, Sendable, Equatable {
  public let items: [FoodPhotoItem]
  public let model: String
  public let promptVersion: String
  public init(items: [FoodPhotoItem], model: String, promptVersion: String) {
    self.items = items
    self.model = model
    self.promptVersion = promptVersion
  }
}
public protocol FoodPhotoGateway: Sendable {
  /// `jpegBase64` is a downscaled JPEG without metadata. Needs a signed-in session.
  func proposeFoodItems(jpegBase64: String) async throws -> FoodPhotoProposal
}
extension CloudGateway: FoodPhotoGateway {}
