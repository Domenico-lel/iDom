import Foundation
import Security

enum RemoteKeychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "it.domenicolella.iDom.pc-remote",
        kSecAttrAccount as String: "configuration-v1"
    ]

    static func read() throws -> PCRemoteConfiguration? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        if status == errSecMissingEntitlement {
            throw RemoteFailure(message: "Questa installazione non consente l’accesso al portachiavi. Reinstalla una versione firmata di iDom.")
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw RemoteFailure(message: "Non riesco ad aprire le credenziali. Sblocca l’iPhone e riprova.")
        }
        return try JSONDecoder().decode(PCRemoteConfiguration.self, from: data)
    }

    static func save(_ configuration: PCRemoteConfiguration) throws {
        let values: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(configuration),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw RemoteFailure(message: "Credenziali non salvate. Riprova con l’iPhone sbloccato.") }
    }

    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RemoteFailure(message: "Non riesco a rimuovere il collegamento. Riprova.")
        }
    }
}

// Reject redirects, including redirects to another HTTPS host: credentials stay at the paired endpoint.
final class RemoteRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class PCRemoteClient {
    private let session: URLSession

    init(configuration config: URLSessionConfiguration = .ephemeral) {
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 12
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.waitsForConnectivity = false
        session = URLSession(configuration: config, delegate: RemoteRedirectGuard(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func status(_ endpoint: RemoteEndpoint, role: String) async throws -> RemoteStatus {
        let data = try await request(endpoint, path: "status")
        let value = try JSONDecoder().decode(RemoteStatus.self, from: data)
        guard value.protocolVersion == 1, value.role == role else {
            throw RemoteFailure(message: "Indirizzo del componente errato o versione non compatibile.")
        }
        return value
    }

    func command(_ endpoint: RemoteEndpoint, action: String) async throws -> String {
        let data = try await request(endpoint, path: action, command: true)
        return try JSONDecoder().decode(RemoteReceipt.self, from: data).message
    }

    private func request(_ endpoint: RemoteEndpoint, path: String, command: Bool = false) async throws -> Data {
        guard endpoint.isValid, let base = endpoint.url else {
            throw RemoteFailure(message: "Completa indirizzo Tailscale e chiave di collegamento.")
        }
        var request = URLRequest(url: base.appendingPathComponent("v1").appendingPathComponent(path))
        request.setValue("Bearer \(endpoint.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if command {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["requestID": UUID().uuidString])
        }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            throw RemoteFailure(message: command
                ? "Conferma non ricevuta: il comando potrebbe essere arrivato. Controlla lo stato prima di riprovare. Verifica anche Tailscale."
                : "Non raggiungibile. Il PC potrebbe essere spento oppure Tailscale o il servizio potrebbero essere scollegati.")
        }
        guard let http = response as? HTTPURLResponse else { throw RemoteFailure(message: "Risposta non riconosciuta.") }
        if http.statusCode == 401 { throw RemoteFailure(message: "Chiave di collegamento errata. Controlla la configurazione.") }
        guard (200...299).contains(http.statusCode), data.count <= 16_384 else {
            throw RemoteFailure(message: "Il componente non ha confermato l’operazione (\(http.statusCode)). Aggiorna lo stato e controlla la configurazione.")
        }
        return data
    }
}
