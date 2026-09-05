import Foundation

@main
struct CoreChecks {
    @MainActor static func main() throws {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            precondition(value(), "FAILED: \(label)")
            checks += 1
            print("PASS \(label)")
        }
        let name = "iDom.Tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("Email|a@example.com\nNota|valore|con separatore", forKey: "quickCopyItems")
        let copy = LocalStore<QuickCopyItem>.quickCopy(defaults: defaults)
        check(copy.items.count == 2, "Legacy texts migrated")
        check(copy.items[1].value == "valore|con separatore", "Migration preserves value separators")
        let firstID = copy.items[0].id
        let restored = LocalStore<QuickCopyItem>.quickCopy(defaults: defaults)
        check(restored.items[0].id == firstID, "Identity survives relaunch")
        var edited = restored.items[0]
        edited.value = "Line 1\nLine 2 | €"
        check(restored.upsert(edited), "Edit saves")
        let again = LocalStore<QuickCopyItem>.quickCopy(defaults: defaults)
        check(again.items.count == 2 && again.items[0].value == edited.value, "Edit preserves multiline and Unicode")
        check(again.remove(id: firstID), "Delete succeeds")
        check(LocalStore<QuickCopyItem>.quickCopy(defaults: defaults).items.count == 1, "Deletion survives relaunch")
        check(defaults.string(forKey: "quickCopyItems") != nil, "Legacy backup retained")
        defaults.set(Data("invalid".utf8), forKey: "broken")
        let broken = LocalStore<Expense>(key: "broken", defaults: defaults)
        check(!broken.isReadable && !broken.replace([]), "Corrupt data cannot be overwritten")
        check(defaults.data(forKey: "broken") == Data("invalid".utf8), "Corrupt original preserved")
        check(Expense.parseAmount("12,50") == 12.5, "Decimal comma")
        check(Expense.parseAmount("12.50") == 12.5, "Decimal point")
        check(Expense.parseAmount(" 0,01 ") == 0.01, "One cent and whitespace")
        for invalid in ["", "-1", "0", "nan", "inf", "1e4", "1.234", "1.234,56", "12,50abc", "999999999999999"] {
            check(Expense.parseAmount(invalid) == nil, "Invalid amount rejected: \(invalid)")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ day: Int, _ month: Int = 9) -> Date { calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))! }
        let food = Expense(title: "Caffè", amount: 0.1, category: "Cibo", date: date(5))
        let food2 = Expense(title: "Altro", amount: 0.2, category: "Cibo", date: date(6))
        let old = Expense(title: "Ago", amount: 2, category: "Auto", date: date(31, 8))
        check(Expense.total([food, food2]) == Decimal(string: "0.3")!, "Currency total has exact cents")
        check(Expense.filtered([old, food, food2], month: date(1), category: nil, calendar: calendar).count == 2, "Monthly filter")
        check(Expense.filtered([old, food, food2], month: nil, category: "Auto", calendar: calendar).map(\.id) == [old.id], "Category filter")
        let invalidLegacy = Expense(title: "Huge legacy", amount: 1e307, category: "Altro")
        check(!invalidLegacy.hasValidAmount, "Oversized legacy amount is flagged")
        check(Expense.total([invalidLegacy, food, food2]) == Decimal(string: "0.3")!, "Oversized legacy amount cannot overflow totals")
        let expenses = LocalStore<Expense>(key: "expenses", defaults: defaults)
        check(expenses.replace([old, food, food2]), "Expense persistence")
        check(expenses.remove(id: food.id) && expenses.items.contains(where: { $0.id == old.id }), "Deletion by identity preserves hidden expenses")
        let legacy = """
        [{"id":"00000000-0000-0000-0000-000000000001","title":"Patente","date":1000,"symbol":"calendar"}]
        """
        let deadline = try JSONDecoder().decode([DeadlineItem].self, from: Data(legacy.utf8))[0]
        check(!deadline.isCompleted && deadline.reminderDate == nil, "Legacy deadline defaults")
        let soon = DeadlineItem(title: "Soon", date: date(6), reminderDate: date(6))
        let later = DeadlineItem(title: "Later", date: date(8), reminderDate: date(7))
        let done = DeadlineItem(title: "Done", date: date(7), reminderDate: date(6), completed: true)
        let past = DeadlineItem(title: "Past", date: date(1), reminderDate: date(1))
        let plans = ReminderPlan.pending([later, done, past, soon, deadline], now: date(5))
        check(plans.map(\.id) == [soon.id, later.id], "Reminders exclude completed, past and disabled")
        check(ReminderPlan.pending([later, soon], now: date(5), limit: 1).first?.id == soon.id, "Nearest reminder fits system limit")
        var updated = soon
        updated.reminderDate = date(9)
        check(ReminderPlan.pending([updated], now: date(5))[0].date == date(9), "Reminder rescheduling uses edited date")
        let deadlines = LocalStore<DeadlineItem>(key: "deadlines", defaults: defaults)
        check(deadlines.replace([updated, done]), "Deadline persistence")
        check(LocalStore<DeadlineItem>(key: "deadlines", defaults: defaults).items[1].isCompleted, "Completion survives relaunch")
        print("\(checks) checks passed")
    }
}
