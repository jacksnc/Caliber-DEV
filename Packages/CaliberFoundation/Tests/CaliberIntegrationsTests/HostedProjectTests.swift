import Foundation
import Testing

@testable import CaliberIntegrations

@Test func selectedProjectRemainsOfflineUntilDeployed() throws {
  let project = try HostedProject(
    projectURL: URL(string: "https://tuvbdozxtkcxnojxbvlh.supabase.co")!, region: "us-east-1",
    gatewayDeployed: false)
  #expect(try project.configuration() == nil)
  #expect(
    project.gatewayURL.absoluteString
      == "https://tuvbdozxtkcxnojxbvlh.supabase.co/functions/v1/caliber-gateway")
  #expect(project.sessionService.hasSuffix(project.projectReference))
  let other = try HostedProject(
    projectURL: URL(string: "https://aaaaaaaaaaaaaaaaaaaa.supabase.co")!, region: "us-east-1",
    gatewayDeployed: true)
  #expect(other.sessionService != project.sessionService)
  #expect(try other.configuration()?.endpoint == other.gatewayURL)
}

@Test(arguments: [
  "http://tuvbdozxtkcxnojxbvlh.supabase.co",
  "https://tuvbdozxtkcxnojxbvlh.supabase.co.attacker.invalid",
  "https://secret@tuvbdozxtkcxnojxbvlh.supabase.co",
  "https://tuvbdozxtkcxnojxbvlh.supabase.co?key=x", "https://tuvbdozxtkcxnojxbvlh.supabase.co/auth",
  "https://tuvbdozxtkcxnojxbvlh.supabase.co:8443",
])
func invalidProjectMetadataFailsClosed(_ url: String) throws {
  let data = try JSONSerialization.data(withJSONObject: [
    "projectURL": url, "region": "us-east-1", "gatewayDeployed": true,
  ])
  #expect(throws: (any Error).self) { try JSONDecoder().decode(HostedProject.self, from: data) }
}
