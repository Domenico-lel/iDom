import Foundation
import Security

enum WhatsAppKeychain {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "it.domenicolella.iDom.whatsapp", kSecAttrAccount as String: "configuration-v1"]
    static func read() throws -> WhatsAppEndpoint? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw RemoteFailure(message: "Portachiavi non disponibile. Sblocca l’iPhone e riapri Messaggi.") }
        return try JSONDecoder().decode(WhatsAppEndpoint.self, from: data)
    }
    static func save(_ endpoint: WhatsAppEndpoint) throws {
        let values: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(endpoint),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound { status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) }
        guard status == errSecSuccess else { throw RemoteFailure(message: "Collegamento non salvato. Riprova con l’iPhone sbloccato.") }
    }
    static func remove() throws {
        let result = SecItemDelete(query as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw RemoteFailure(message: "Collegamento non rimosso.") }
    }
}

final class WhatsAppClient {
    private let session: URLSession
    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = 10; configuration.timeoutIntervalForResource = 15
        configuration.httpShouldSetCookies = false; configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration, delegate: RemoteRedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    func status(_ endpoint: WhatsAppEndpoint) async throws -> WhatsAppStatus {
        let value = try JSONDecoder().decode(WhatsAppStatus.self, from: await request(endpoint, path: "status"))
        guard value.protocolVersion == 1, value.role == "whatsapp" else { throw RemoteFailure(message: "Questo indirizzo non è il componente WhatsApp. Usa la porta 8444.") }
        return value
    }
    func schedule(_ endpoint: WhatsAppEndpoint, message: WhatsAppRequest) async throws -> WhatsAppJob {
        try JSONDecoder().decode(WhatsAppJob.self, from: await request(endpoint, path: "jobs", body: JSONEncoder().encode(message)))
    }
    func cancel(_ endpoint: WhatsAppEndpoint, id: String) async throws {
        guard UUID(uuidString: id) != nil else { throw RemoteFailure(message: "Messaggio non valido.") }
        _ = try await request(endpoint, path: "jobs/\(id)/cancel", body: Data("{}".utf8))
    }
    private func request(_ endpoint: WhatsAppEndpoint, path: String, body: Data? = nil) async throws -> Data {
        guard endpoint.isValid, let base = endpoint.url else { throw RemoteFailure(message: "Inserisci indirizzo HTTPS Tailscale con porta 8444 e chiave di 64 caratteri.") }
        var request = URLRequest(url: base.appendingPathComponent("v1/" + path))
        request.setValue("Bearer \(endpoint.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            throw RemoteFailure(message: body == nil ? "PC non raggiungibile. Controlla Tailscale e il componente WhatsApp sul PC."
                : "Conferma non ricevuta. La richiesta potrebbe essere arrivata: aggiorna lo stato prima di riprovare.")
        }
        guard let http = response as? HTTPURLResponse, data.count <= 32_000_000 else { throw RemoteFailure(message: "Risposta del PC non valida.") }
        if http.statusCode == 401 { throw RemoteFailure(message: "Chiave errata: usa la chiave del componente WhatsApp, distinta da PC Remote.") }
        if http.statusCode == 502 && body == nil {
            throw RemoteFailure(message: "Il collegamento HTTPS risponde, ma il componente WhatsApp sul PC non è raggiungibile (502). Controlla che sia avviato e che Tailscale Serve punti alla porta 47322.")
        }
        guard (200...299).contains(http.statusCode) else {
            let problem = try? JSONDecoder().decode([String: String].self, from: data)
            let text = problem?["error"] ?? "Operazione non confermata dal PC (\(http.statusCode))."
            if (400...499).contains(http.statusCode) { throw WhatsAppRejected(message: text) }
            throw RemoteFailure(message: text)
        }
        return data
    }
}
