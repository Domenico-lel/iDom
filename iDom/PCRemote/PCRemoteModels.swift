import Foundation

struct RemoteEndpoint: Codable, Equatable {
    var address = ""
    var token = ""

    var url: URL? {
        guard let parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme == "https", let host = parts.host?.lowercased(),
              host.hasSuffix(".ts.net"), !host.contains("%"),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/",
              parts.port == nil || parts.port == 8443,
              host.split(separator: ".").count >= 4 else { return nil }
        return parts.url
    }

    var isValid: Bool {
        url != nil && token.count == 64 && token.allSatisfy { $0.isASCII && $0.isHexDigit }
    }
}

struct PCRemoteConfiguration: Codable, Equatable {
    var pc = RemoteEndpoint()
    var wake = RemoteEndpoint()
    var wakeEnabled = false
    var isValid: Bool { pc.isValid && (!wakeEnabled || wake.isValid) }
}

struct RemoteStatus: Decodable {
    let protocolVersion: Int
    let role: String
    let name: String
    let simulated: Bool
    let shutdownRemaining: Int?
    let lastError: String?
}

struct RemoteReceipt: Decodable {
    let message: String
}

struct RemoteFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
