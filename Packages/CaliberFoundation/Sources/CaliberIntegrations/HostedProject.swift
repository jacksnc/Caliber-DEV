import Foundation

/// Public deployment metadata only. API keys stay on the server.
public struct HostedProject: Codable, Equatable, Sendable {
  public let projectURL: URL
  public let region: String
  public let gatewayDeployed: Bool

  public init(projectURL: URL, region: String, gatewayDeployed: Bool) throws {
    guard projectURL.scheme == "https", projectURL.user == nil, projectURL.password == nil,
      projectURL.port == nil, projectURL.query == nil, projectURL.fragment == nil,
      projectURL.path.isEmpty || projectURL.path == "/",
      let host = projectURL.host,
      host.range(of: "^[a-z0-9]{20}\\.supabase\\.co$", options: .regularExpression) != nil,
      region.range(of: "^[a-z]{2}(?:-[a-z]+)+-[0-9]+$", options: .regularExpression) != nil
    else { throw GatewayError.insecureEndpoint }
    self.projectURL = projectURL
    self.region = region
    self.gatewayDeployed = gatewayDeployed
  }

  // Codable must pass the same checks as a manually constructed value.
  private enum CodingKeys: CodingKey { case projectURL, region, gatewayDeployed }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      projectURL: container.decode(URL.self, forKey: .projectURL),
      region: container.decode(String.self, forKey: .region),
      gatewayDeployed: container.decode(Bool.self, forKey: .gatewayDeployed))
  }
  public var projectReference: String { String(projectURL.host!.prefix(20)) }
  public var sessionService: String { "Caliber.Foundation.Session." + projectReference }
  public var gatewayURL: URL {
    projectURL.appendingPathComponent("functions/v1/caliber-gateway")
  }
  public func configuration() throws -> CloudConfiguration? {
    gatewayDeployed ? try CloudConfiguration(endpoint: gatewayURL, region: region) : nil
  }
}
