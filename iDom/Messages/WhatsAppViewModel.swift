import Foundation
import Combine

@MainActor
final class WhatsAppViewModel: ObservableObject {
    @Published private(set) var endpoint: WhatsAppEndpoint?
    @Published private(set) var status: WhatsAppStatus?
    @Published private(set) var reachable = false
    @Published private(set) var busy = false
    @Published private(set) var readable = true
    @Published private(set) var pending: WhatsAppPending?
    @Published var issue: AppIssue?
    @Published var connectionMessage: String?
    private let client = WhatsAppClient()
    private let pendingKey = "idom.whatsapp.pending-v1"
    private var refreshing = false
    var canSchedule: Bool { readable && reachable && !busy && pending == nil && status?.connection == "ready" && status?.error == nil }
    init() {
        do {
            endpoint = try WhatsAppKeychain.read()
            if let data = UserDefaults.standard.data(forKey: pendingKey) { pending = try JSONDecoder().decode(WhatsAppPending.self, from: data) }
            else if UserDefaults.standard.object(forKey: pendingKey) != nil { throw CocoaError(.fileReadCorruptFile) }
            if let pending, pending.address != endpoint?.address { throw RemoteFailure(message: "Richiesta in sospeso associata a un altro collegamento. Dati conservati.") }
        } catch { readable = false; issue = .init(message: error.localizedDescription) }
    }
    func configure(_ value: WhatsAppEndpoint) async -> Bool {
        guard readable, pending == nil, !busy, value.isValid else { return false }
        busy = true; defer { busy = false }
        do {
            let checked = try await client.status(value)
            try WhatsAppKeychain.save(value)
            endpoint = value; status = checked; reachable = true; connectionMessage = nil
            return true
        } catch { issue = .init(message: error.localizedDescription); return false }
    }
    func refresh() async {
        guard readable, let endpoint, !refreshing, !busy else { return }
        refreshing = true; defer { refreshing = false }
        do {
            let result = try await client.status(endpoint)
            guard self.endpoint == endpoint else { return }
            status = result; reachable = true; connectionMessage = nil
            if let pending, result.jobs.contains(where: { $0.id == pending.request.id }) { clearPending() }
        } catch {
            guard self.endpoint == endpoint, !Task.isCancelled else { return }
            reachable = false; connectionMessage = error.localizedDescription
        }
    }
    func schedule(_ draft: WhatsAppDraft) async -> Bool {
        guard canSchedule, let endpoint, draft.isValid else { return false }
        do {
            let value = WhatsAppPending(address: endpoint.address, request: draft.request)
            UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: pendingKey)
            pending = value
        } catch { issue = .init(message: "Richiesta non salvata sull’iPhone: nessun invio programmato."); return false }
        await retryPending()
        return true
    }
    func retryPending() async {
        guard readable, let pending, let endpoint, endpoint.address == pending.address, !busy else { return }
        busy = true
        do {
            _ = try await client.schedule(endpoint, message: pending.request)
            clearPending()
        } catch let rejection as WhatsAppRejected {
            // A definitive rejection did not enqueue this request. Keep the text as a local draft.
            let drafts = LocalStore<WhatsAppDraft>(key: "idom.scheduledWhatsApp")
            let preserved = drafts.upsert(.init(id: UUID(uuidString: pending.request.id) ?? UUID(), recipient: pending.request.recipient,
                message: pending.request.message, scheduledAt: Date(timeIntervalSince1970: Double(pending.request.scheduledAt) / 1000)))
            if preserved { clearPending() }
            issue = .init(message: rejection.message + (preserved ? " Testo conservato nelle bozze locali." : " La richiesta locale è conservata."))
        } catch { issue = .init(message: error.localizedDescription) }
        busy = false
        await refresh()
    }
    private func clearPending() { UserDefaults.standard.removeObject(forKey: pendingKey); pending = nil }
    func cancel(_ job: WhatsAppJob) async {
        guard let endpoint, !busy, reachable else { return }
        busy = true
        do { try await client.cancel(endpoint, id: job.id) }
        catch { issue = .init(message: error.localizedDescription) }
        busy = false
        await refresh()
    }
    func removeConnection() {
        guard readable, !busy, pending == nil else { return }
        do { try WhatsAppKeychain.remove(); endpoint = nil; status = nil; reachable = false; connectionMessage = nil }
        catch { issue = .init(message: error.localizedDescription) }
    }
}
