import Foundation

@main
struct WhatsAppChecks {
    static func main() async throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            precondition(condition(), name); checks += 1; print("PASS \(name)")
        }
        let token = String(repeating: "a", count: 64)
        check(WhatsAppEndpoint(address: "https://pc.example.ts.net:8444", token: token).isValid, "WhatsApp dedicated endpoint")
        for address in ["http://pc.example.ts.net:8444", "https://pc.example.ts.net:8443", "https://pc.example.ts.net", "https://example.com:8444", "https://a.ts.net:8444", "https://pc.example.ts.net:8444/path", "https://pc.example.ts.net:8444?q=1", "https://user@pc.example.ts.net:8444", "https://pc.example.ts.net:8444#fragment"] {
            check(!WhatsAppEndpoint(address: address, token: token).isValid, "Reject \(address)")
        }
        check(!WhatsAppEndpoint(address: "https://pc.example.ts.net:8444", token: "short").isValid, "Reject invalid key")
        check(WhatsAppDraft.phone("+39 (333) 123-4567") == "393331234567", "Normalize international phone")
        check(WhatsAppDraft.phone("00393331234567") == "393331234567", "Normalize 00 prefix")
        for number in ["+0123456789", "123", "+393331234567@g.us", "++393331234567", "1234567890123456"] {
            check(WhatsAppDraft.phone(number) == nil, "Reject invalid phone \(number)")
        }
        var draft = WhatsAppDraft(recipient: "+393331234567", message: "Caffè & 👋\nProva", scheduledAt: Date().addingTimeInterval(60))
        check(draft.isValid, "Valid draft")
        let encoded = try JSONEncoder().encode(draft.request)
        let request = try JSONDecoder().decode(WhatsAppRequest.self, from: encoded)
        check(request.message == draft.message, "Unicode message preserved")
        check(request.id == draft.id.uuidString.lowercased(), "Stable idempotency ID")
        check(abs(Double(request.scheduledAt) / 1000 - draft.scheduledAt.timeIntervalSince1970) < 0.002, "Milliseconds cross-platform")
        draft.message = String(repeating: "a", count: 4097); check(!draft.isValid, "Message length limit")
        draft.message = " \n "; check(!draft.isValid, "Blank text rejected")
        draft.message = "hello"; draft.scheduledAt = Date().addingTimeInterval(-1); check(!draft.isValid, "Past schedule rejected")
        let legacy = """
        [{"id":"8EE9A49D-C278-4AC3-9413-06BB84B7AEBF","recipient":"+393331234567","message":"Old draft","scheduledAt":700000000}]
        """.data(using: .utf8)!
        let old = try JSONDecoder().decode([WhatsAppDraft].self, from: legacy)
        check(old[0].message == "Old draft", "Legacy drafts remain readable")
        let status = """
        {"protocolVersion":1,"role":"whatsapp","name":"PC","simulated":false,"connection":"ready","account":"393331234567","jobs":[{"id":"abc","recipient":"393331234567","message":"Test","scheduledAt":1800000000000,"state":"uncertain"}]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WhatsAppStatus.self, from: status)
        check(decoded.jobs[0].title == "Esito da verificare", "Ambiguous sends not labelled successful")
        check(decoded.jobs[0].date.timeIntervalSince1970 == 1800000000, "Server dates decoded")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WhatsAppStub.self]
        let client = WhatsAppClient(configuration: configuration)
        let endpoint = WhatsAppEndpoint(address: "https://pc.example.ts.net:8444", token: token)
        WhatsAppStub.response = (200, status)
        let remote = try await client.status(endpoint)
        check(remote.connection == "ready", "Client decodes status from paired service")
        check(WhatsAppStub.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer " + token, "Client authenticates at dedicated endpoint")
        check(WhatsAppStub.lastRequest?.url?.path == "/v1/status", "Client status route")
        WhatsAppStub.response = (200, Data("{\"protocolVersion\":1,\"role\":\"pc\",\"name\":\"PC\",\"simulated\":false,\"connection\":\"ready\",\"jobs\":[]}".utf8))
        do { _ = try await client.status(endpoint); check(false, "Wrong role rejected") }
        catch { check(true, "Wrong role rejected") }
        WhatsAppStub.response = (401, Data("{}".utf8))
        do { _ = try await client.status(endpoint); check(false, "Wrong key rejected") }
        catch { check(error.localizedDescription.contains("Chiave"), "Wrong key explained") }
        WhatsAppStub.response = (200, Data("{\"id\":\"job\",\"recipient\":\"393331234567\",\"message\":\"Test\",\"scheduledAt\":1800000000000,\"state\":\"queued\"}".utf8))
        _ = try await client.schedule(endpoint, message: request)
        check(WhatsAppStub.lastRequest?.httpMethod == "POST", "Scheduling requires POST")
        check(WhatsAppStub.lastRequest?.url?.path == "/v1/jobs", "Scheduling route")
        let captured = try JSONDecoder().decode(WhatsAppRequest.self, from: WhatsAppStub.lastBody)
        check(captured == request, "Client sends exact payload and stable ID")
        WhatsAppStub.response = (409, Data("{\"error\":\"Collega WhatsApp\"}".utf8))
        do { _ = try await client.schedule(endpoint, message: request); check(false, "Definitive rejection") }
        catch { check(error is WhatsAppRejected, "Definitive rejection distinguished from lost response") }
        WhatsAppStub.response = (503, Data("{\"error\":\"Non pronto\"}".utf8))
        do { _ = try await client.schedule(endpoint, message: request); check(false, "Uncertain request retained") }
        catch { check(!(error is WhatsAppRejected), "Uncertain request retained") }
        print("\(checks) WhatsApp checks passed")
    }
}

final class WhatsAppStub: URLProtocol, @unchecked Sendable {
    static var response: (Int, Data) = (200, Data())
    static var lastRequest: URLRequest?
    static var lastBody = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                Self.lastBody.append(buffer, count: count)
            }
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.response.0, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.response.1)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
