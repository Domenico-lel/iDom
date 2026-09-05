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
        print("\(checks) WhatsApp checks passed")
    }
}
