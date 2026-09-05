import Foundation
import Combine
import UserNotifications

@MainActor
final class DeadlineReminders: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = DeadlineReminders()
    @Published private(set) var message: String?
    @Published private(set) var denied = false
    private let center = UNUserNotificationCenter.current()
    private var scheduledWork: Task<Void, Never>?
    private let prefix = "idom.deadline."

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() async -> Bool {
        do { return try await center.requestAuthorization(options: [.alert, .sound]) }
        catch {
            message = "Impossibile richiedere le notifiche. Riprova dalle Scadenze."
            return false
        }
    }

    // Serialize reconciliation so a late add cannot resurrect an edited/deleted reminder.
    func refresh() async {
        let previous = scheduledWork
        let next = Task { @MainActor in
            await previous?.value
            await self.reconcile()
        }
        scheduledWork = next
        await next.value
    }

    private func reconcile() async {
        let items: [DeadlineItem]
        do {
            if let data = UserDefaults.standard.data(forKey: "idom.deadlines") {
                items = try JSONDecoder().decode([DeadlineItem].self, from: data)
            } else if UserDefaults.standard.object(forKey: "idom.deadlines") != nil {
                throw CocoaError(.fileReadCorruptFile)
            } else { items = [] }
        } catch {
            message = "Non riesco a leggere le scadenze: i promemoria esistenti non sono stati modificati."
            return
        }
        let settings = await center.notificationSettings()
        denied = settings.authorizationStatus == .denied
        let requests = await center.pendingNotificationRequests()
        let ours = requests.filter { $0.identifier.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours.map(\.identifier))
        let activeIDs = Set(items.filter { !$0.isCompleted && $0.reminderDate != nil }.map { prefix + $0.id.uuidString })
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) && !activeIDs.contains($0) })
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else {
            message = denied ? "Le notifiche sono disattivate. Abilitale nelle Impostazioni dell’iPhone per ricevere i promemoria." : nil
            return
        }
        let now = Date()
        let available = max(0, min(60, 64 - requests.filter { !$0.identifier.hasPrefix(prefix) }.count))
        let all = ReminderPlan.pending(items, now: now, limit: Int.max)
        let plan = Array(all.prefix(available))
        var failed = false
        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "Controlla la tua scadenza in iDom."
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: prefix + reminder.id.uuidString, content: content, trigger: trigger))
            } catch { failed = true }
        }
        if failed { message = "Alcuni promemoria non sono stati programmati. Riapri Scadenze per riprovare." }
        else if all.count > plan.count { message = "Sono programmati i prossimi \(plan.count) promemoria. Apri iDom periodicamente per programmare i successivi." }
        else { message = nil }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
