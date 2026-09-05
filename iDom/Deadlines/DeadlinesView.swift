import SwiftUI

struct DeadlinesView: View {
    @StateObject private var store = LocalStore<DeadlineItem>(key: "idom.deadlines")
    @ObservedObject private var reminders = DeadlineReminders.shared
    @Environment(\.openURL) private var openURL
    @State private var editor: DeadlineItem?
    @State private var deleting: DeadlineItem?
    @State private var query = ""
    @State private var showCompleted = false
    private var results: [DeadlineItem] {
        store.items.filter { $0.isCompleted == showCompleted && (query.isEmpty || $0.title.localizedStandardContains(query)) }
            .sorted { $0.date < $1.date }
    }
    var body: some View {
        List {
            if !store.isReadable { StorageErrorBanner() }
            if let message = reminders.message {
                Section {
                    Label(message, systemImage: "bell.badge").font(.callout)
                    if reminders.denied {
                        Button("Apri impostazioni notifiche") { if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) } }
                    }
                }
            }
            Section {
                Picker("Mostra", selection: $showCompleted) {
                    Text("Da fare").tag(false)
                    Text("Completate").tag(true)
                }.pickerStyle(.segmented)
            }
            Section("Tocca per modificare · Scorri per completare") {
                if results.isEmpty && store.isReadable {
                    ContentUnavailableView(query.isEmpty ? (showCompleted ? "Nessuna scadenza completata" : "Nessuna scadenza da fare") : "Nessun risultato", systemImage: "calendar.badge.checkmark", description: Text("Aggiungi una scadenza con + oppure cambia filtro."))
                }
                ForEach(results) { item in
                    Button { editor = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "calendar")
                                .foregroundStyle(item.isCompleted ? Color.green : Color.red)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).font(.headline).foregroundStyle(.primary)
                                Text(item.date, style: .date).font(.caption).foregroundStyle(.secondary)
                                if let date = item.reminderDate, !item.isCompleted {
                                    Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: date > .now ? "bell" : "bell.slash")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 4)
                            Text(daysText(item)).font(.caption.weight(.semibold))
                                .foregroundStyle(!item.isCompleted && Calendar.current.startOfDay(for: item.date) < Calendar.current.startOfDay(for: .now) ? Color.red : Color.secondary)
                        }.padding(.vertical, 5)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button(item.isCompleted ? "Riapri" : "Completa") {
                            var value = item
                            value.completed = !item.isCompleted
                            if store.upsert(value) { Task { await reminders.refresh() } }
                        }.tint(.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Elimina", role: .destructive) { deleting = item }
                    }
                }
            }
        }
        .navigationTitle("Scadenze")
        .searchable(text: $query, prompt: "Cerca scadenze")
        .toolbar {
            Button("Aggiungi scadenza", systemImage: "plus") {
                editor = DeadlineItem(title: "", date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
            }.disabled(!store.isReadable)
        }
        .sheet(item: $editor) { item in
            DeadlineEditor(item: item, isNew: !store.items.contains { $0.id == item.id }) { value in
                guard store.upsert(value) else { return false }
                showCompleted = value.isCompleted
                query = ""
                Task { await reminders.refresh() }
                return true
            }
        }
        .alert("Eliminare questa scadenza?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Elimina", role: .destructive) {
                if let item = deleting, store.remove(id: item.id) { Task { await reminders.refresh() } }
                deleting = nil
            }
            Button("Annulla", role: .cancel) { deleting = nil }
        } message: { Text("Verrà rimosso anche il relativo promemoria.") }
        .storageAlert($store.issue)
        .task { await reminders.refresh() }
    }
    private func daysText(_ item: DeadlineItem) -> String {
        if item.isCompleted { return "Fatto" }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: item.date)).day ?? 0
        if days < 0 { return "Scaduta" }
        if days == 0 { return "Oggi" }
        if days == 1 { return "Domani" }
        return "\(days) gg"
    }
}

private struct DeadlineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State var item: DeadlineItem
    @State private var enabled: Bool
    @State private var reminder: Date
    @State private var busy = false
    @State private var issue: AppIssue?
    let isNew: Bool
    let onSave: (DeadlineItem) -> Bool
    init(item: DeadlineItem, isNew: Bool, onSave: @escaping (DeadlineItem) -> Bool) {
        _item = State(initialValue: item)
        _enabled = State(initialValue: item.reminderDate != nil)
        _reminder = State(initialValue: item.reminderDate ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: item.date) ?? item.date)
        self.isNew = isNew
        self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $item.title).accessibilityIdentifier("deadline.title")
                DatePicker("Scadenza", selection: $item.date, displayedComponents: .date)
                Toggle("Completata", isOn: Binding(get: { item.isCompleted }, set: { item.completed = $0 }))
                if !item.isCompleted {
                    Section {
                        Toggle("Ricordami", isOn: $enabled)
                        if enabled {
                            DatePicker("Avvisami il", selection: $reminder, displayedComponents: [.date, .hourAndMinute])
                            if reminder <= .now { Text("Scegli un orario futuro per ricevere il promemoria.").font(.caption).foregroundStyle(.red) }
                        }
                    } footer: {
                        Text("Il promemoria arriva su questo iPhone anche con iDom chiusa, se le notifiche sono consentite. L'orario è indipendente dalla data di scadenza.")
                    }
                    if DeadlineReminders.shared.denied && enabled {
                        Button("Apri impostazioni notifiche") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                }
                if busy { ProgressView("Salvataggio…") }
            }
            .disabled(busy)
            .navigationTitle(isNew ? "Nuova scadenza" : "Modifica scadenza")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(busy)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { Task { await save() } }
                        .disabled(busy || item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (enabled && !item.isCompleted && reminder <= .now))
                }
            }
            .storageAlert($issue)
        }
    }
    @MainActor private func save() async {
        busy = true
        defer { busy = false }
        if enabled && !item.isCompleted {
            guard await DeadlineReminders.shared.requestPermission() else {
                await DeadlineReminders.shared.refresh()
                issue = AppIssue(message: "Notifiche non consentite. Abilitale nelle Impostazioni, oppure disattiva Ricordami per salvare senza notifica.")
                return
            }
        }
        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.reminderDate = enabled ? reminder : nil
        if onSave(item) { dismiss() }
        else { issue = AppIssue(message: "Salvataggio non riuscito. I dati precedenti sono conservati.") }
    }
}
