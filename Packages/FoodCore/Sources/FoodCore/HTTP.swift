import Foundation

/// Minimal request/response types so the package never touches URLSession (which lives in a separate module on Linux)
/// and every network path can be tested with a scripted transport. The app supplies a URLSession-backed transport.
public struct HTTPRequest: Equatable, Sendable {
    public var url: URL
    public var headers: [String: String]
    public var timeout: TimeInterval

    public init(url: URL, headers: [String: String] = [:], timeout: TimeInterval = 8) {
        self.url = url
        self.headers = headers
        self.timeout = timeout
    }
}

public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public enum LookupError: Error, Equatable, Sendable {
    /// Network failure, timeout or a 5xx: worth retrying later.
    case unavailable(String)
    /// 429 or an explicit quota message: back off.
    case rateLimited
    /// 401/403: the API key is missing or wrong. Retrying will not help.
    case unauthorized
    /// A response that could not be understood.
    case malformed(String)
}
