import Foundation

final class RemoteStubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@main
struct RemoteChecks {
    static func main() async throws {
        var checks = 0
        func check(_ value: Bool, _ label: String) {
            precondition(value, label)
            checks += 1
            print("PASS \(label)")
        }
        let token = String(repeating: "a", count: 64)
        let endpoint = RemoteEndpoint(address: "https://desktop.tail123.ts.net:8443", token: token)
        check(endpoint.isValid, "Private Tailscale HTTPS endpoint accepted")
        for bad in ["http://desktop.tail123.ts.net", "https://example.org", "https://desktop.tail123.ts.net.evil.org", "https://user:secret@desktop.tail123.ts.net", "https://desktop.tail123.ts.net/path", "https://desktop.tail123.ts.net?token=x", "https://desktop.tail123.ts.net#fragment", "https://desktop.tail123.ts.net:80"] {
            check(!RemoteEndpoint(address: bad, token: token).isValid, "Unsafe endpoint rejected: \(bad)")
        }
        check(!RemoteEndpoint(address: endpoint.address, token: "short").isValid, "Short pairing token rejected")
        check(!RemoteEndpoint(address: endpoint.address, token: String(repeating: "z", count: 64)).isValid, "Nonhex token rejected")
        let config = PCRemoteConfiguration(pc: endpoint)
        check(config.isValid, "Shutdown usable without wake relay")
        var wakeConfig = config
        wakeConfig.wakeEnabled = true
        check(!wakeConfig.isValid, "Enabling wake requires configured relay")
        wakeConfig.wake = endpoint
        check(wakeConfig.isValid, "Complete relay config accepted")
        check(try JSONDecoder().decode(PCRemoteConfiguration.self, from: JSONEncoder().encode(wakeConfig)) == wakeConfig, "Pairing roundtrip")
        let status = try JSONDecoder().decode(RemoteStatus.self, from: Data("""
        {"protocolVersion":1,"role":"pc","name":"PC","simulated":false,"shutdownRemaining":30,"lastError":null}
        """.utf8))
        check(status.shutdownRemaining == 30 && !status.simulated, "Companion status decoded")
        let transport = URLSessionConfiguration.ephemeral
        transport.protocolClasses = [RemoteStubProtocol.self]
        let client = PCRemoteClient(configuration: transport)
        RemoteStubProtocol.handler = { request in
            precondition(request.url?.path == "/v1/status")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + token)
            return (200, Data("{\"protocolVersion\":1,\"role\":\"pc\",\"name\":\"PC test\",\"simulated\":true}".utf8))
        }
        let remote = try await client.status(endpoint, role: "pc")
        check(remote.simulated, "Authenticated transport decodes simulation explicitly")
        do { _ = try await client.status(endpoint, role: "wake"); preconditionFailure("Role mismatch accepted") }
        catch { check(error is RemoteFailure, "Wrong endpoint role rejected") }
        RemoteStubProtocol.handler = { _ in (401, Data()) }
        do { _ = try await client.status(endpoint, role: "pc"); preconditionFailure("Bad key accepted") }
        catch { check(error.localizedDescription.contains("Chiave"), "Authentication failure explained") }
        RemoteStubProtocol.handler = { _ in (302, Data()) }
        do { _ = try await client.status(endpoint, role: "pc"); preconditionFailure("Redirect accepted") }
        catch { check(error is RemoteFailure, "Redirect response not treated as success") }
        RemoteStubProtocol.handler = { _ in throw URLError(.timedOut) }
        do { _ = try await client.command(endpoint, action: "shutdown"); preconditionFailure("Timeout accepted") }
        catch { check(error.localizedDescription.contains("potrebbe"), "Command timeout reports uncertain delivery") }
        RemoteStubProtocol.handler = { request in
            precondition(request.httpMethod == "POST")
            precondition(request.url?.path == "/v1/cancel")
            precondition(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            return (200, Data("{\"message\":\"Annullato\"}".utf8))
        }
        check(try await client.command(endpoint, action: "cancel") == "Annullato", "Explicit POST command confirms receipt")
        print("\(checks) PC Remote checks passed")
    }
}
