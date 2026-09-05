import Foundation
import Combine

struct QuickCopyItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var value: String
}

struct DeadlineItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
    var symbol = "calendar"
    // Optional fields preserve decoding of version 0.2.1 data.
    var reminderDate: Date?
    var completed: Bool?
    var isCompleted: Bool { completed ?? false }
}

struct Expense: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var amount: Double
    var category: String
    var date = Date()
    var hasValidAmount: Bool { amount.isFinite && amount > 0 && amount <= 999_999_999.99 }
    static let categories = ["Cibo", "Auto", "Casa", "Svago", "Tech", "Altro"]

    // Accept decimal comma or point, never silently interpret ambiguous thousands.
    static func parseAmount(_ input: String) -> Double? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]+([.,][0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let number = Double(text.replacingOccurrences(of: ",", with: ".")),
              number.isFinite, number > 0, number <= 999_999_999.99 else { return nil }
        return (number * 100).rounded() / 100
    }

    static func total(_ items: [Expense]) -> Decimal {
        items.reduce(Decimal.zero) { result, item in
            guard item.hasValidAmount else { return result }
            return result + Decimal((item.amount * 100).rounded()) / 100
        }
    }

    static func filtered(_ items: [Expense], month: Date?, category: String?, calendar: Calendar = .current) -> [Expense] {
        items.filter { item in
            (month == nil || calendar.isDate(item.date, equalTo: month!, toGranularity: .month)) &&
            (category == nil || category == item.category)
        }.sorted { $0.date > $1.date }
    }
}

struct AppIssue: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
final class LocalStore<Item: Codable & Identifiable>: ObservableObject where Item.ID == UUID {
    @Published private(set) var items: [Item] = []
    @Published var issue: AppIssue?
    @Published private(set) var isReadable = true
    private let key: String
    private let defaults: UserDefaults

    init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
        do {
            if let data = defaults.data(forKey: key) {
                items = try JSONDecoder().decode([Item].self, from: data)
            } else if defaults.object(forKey: key) != nil {
                throw CocoaError(.fileReadCorruptFile)
            }
        } catch {
            isReadable = false
            issue = AppIssue(message: "Non riesco a leggere i dati salvati. Gli originali sono conservati; le modifiche sono bloccate per non sovrascriverli.")
        }
    }

    @discardableResult
    func replace(_ values: [Item]) -> Bool {
        guard isReadable else { return false }
        do {
            let data = try JSONEncoder().encode(values)
            defaults.set(data, forKey: key)
            items = values
            return true
        } catch {
            issue = AppIssue(message: "Salvataggio non riuscito. I dati precedenti sono rimasti invariati.")
            return false
        }
    }

    @discardableResult
    func upsert(_ value: Item) -> Bool {
        var values = items
        if let index = values.firstIndex(where: { $0.id == value.id }) { values[index] = value }
        else { values.append(value) }
        return replace(values)
    }

    @discardableResult
    func remove(id: UUID) -> Bool { replace(items.filter { $0.id != id }) }
}

extension LocalStore where Item == QuickCopyItem {
    static func quickCopy(defaults: UserDefaults = .standard) -> LocalStore<QuickCopyItem> {
        let key = "idom.quickCopy.v2"
        let store = LocalStore<QuickCopyItem>(key: key, defaults: defaults)
        guard defaults.object(forKey: key) == nil else { return store }
        // Keep the old value as a backup; only migrate once, preserving separators in values.
        if let legacy = defaults.string(forKey: "quickCopyItems") {
            let lines = legacy.split(separator: "\n", omittingEmptySubsequences: true)
            let migrated = lines.compactMap { line -> QuickCopyItem? in
                let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }
                return QuickCopyItem(title: String(parts[0]), value: String(parts[1]))
            }
            guard migrated.count == lines.count else {
                store.isReadable = false
                store.issue = AppIssue(message: "Alcuni vecchi testi non sono leggibili. I dati originali sono conservati; la migrazione è stata interrotta.")
                return store
            }
            store.replace(migrated)
        } else {
            store.replace([])
        }
        return store
    }
}

struct ReminderPlan: Equatable {
    let id: UUID
    let title: String
    let date: Date

    static func pending(_ items: [DeadlineItem], now: Date = .now, limit: Int = 60) -> [ReminderPlan] {
        Array(items.compactMap { item -> ReminderPlan? in
            guard !item.isCompleted, let date = item.reminderDate, date > now else { return nil }
            return ReminderPlan(id: item.id, title: item.title, date: date)
        }.sorted { $0.date < $1.date }.prefix(max(0, limit)))
    }
}
