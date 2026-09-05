import Foundation

struct WhatsAppEndpoint: Codable, Equatable {
    var address = ""
    var token = ""
    var url: URL? {
        guard let parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme == "https", let host = parts.host?.lowercased(), host.hasSuffix(".ts.net"),
              host.split(separator: ".").count >= 4, !host.contains("%"),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/", parts.port == 8444 else { return nil }
        return parts.url
    }
    var isValid: Bool { url != nil && token.count == 64 && token.allSatisfy { $0.isASCII && $0.isHexDigit } }
}

struct WhatsAppDraft: Identifiable, Codable, Equatable {
    var id = UUID()
    var recipient = ""
    var message = ""
    var scheduledAt = Date().addingTimeInterval(3600)
    var isValid: Bool {
        Self.phone(recipient) != nil && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        message.utf16.count <= 4096 && scheduledAt > Date().addingTimeInterval(10) &&
        scheduledAt < Date().addingTimeInterval(366 * 86400)
    }
    static func phone(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "+0123456789 ()-.").contains($0) }) else { return nil }
        text = text.filter { !" ()-.".contains($0) }
        if text.hasPrefix("+") { text.removeFirst() }
        else if text.hasPrefix("00") { text.removeFirst(2) }
        guard (7...15).contains(text.count), text.first != "0", text.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
        return text
    }
    var request: WhatsAppRequest {
        .init(id: id.uuidString.lowercased(), recipient: Self.phone(recipient) ?? recipient,
              message: message, scheduledAt: Int64((scheduledAt.timeIntervalSince1970 * 1000).rounded()))
    }
}

struct WhatsAppRequest: Codable, Equatable {
    let id: String
    let recipient: String
    let message: String
    let scheduledAt: Int64
}

struct WhatsAppJob: Decodable, Identifiable {
    let id: String
    let recipient: String
    let message: String
    let scheduledAt: Double
    let state: String
    let detail: String?
    var date: Date { Date(timeIntervalSince1970: scheduledAt / 1000) }
    var title: String {
        switch state {
        case "queued": "Programmato sul PC"
        case "sending": "Invio in corso"
        case "submitted": "Affidato a WhatsApp"
        case "delivered": "Consegnato"
        case "read": "Letto"
        case "uncertain": "Esito da verificare"
        case "failed": "Non inviato"
        case "missed": "Orario trascorso · non inviato"
        case "cancelled": "Annullato"
        case "simulated": "Simulazione · non inviato"
        default: "Stato non riconosciuto"
        }
    }
}

struct WhatsAppStatus: Decodable {
    let protocolVersion: Int
    let role: String
    let name: String
    let simulated: Bool
    let connection: String
    let error: String?
    let account: String?
    let jobs: [WhatsAppJob]
}

struct WhatsAppPending: Codable {
    let address: String
    let request: WhatsAppRequest
}

struct WhatsAppRejected: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
