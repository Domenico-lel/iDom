import SwiftUI

private struct ScheduledWhatsAppMessage: Identifiable, Codable {
    var id = UUID()
    var recipient: String
    var message: String
    var scheduledAt: Date
}

struct ScheduledMessagesView: View {
    @State private var items: [ScheduledWhatsAppMessage] = []
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                Label("Invio WhatsApp programmato", systemImage: "clock.badge.checkmark")
                    .font(.headline)
                Text("iOS non permette a iDom di inviare autonomamente un normale messaggio WhatsApp in background. iDom può però salvare la programmazione e ricordarti di completare l'invio. L'invio automatico richiederà un servizio/API WhatsApp compatibile.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Programmati") {
                if items.isEmpty {
                    ContentUnavailableView("Nessun messaggio", systemImage: "message.badge", description: Text("Programma il tuo primo messaggio."))
                } else {
                    ForEach(items.sorted { $0.scheduledAt < $1.scheduledAt }) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(item.recipient).font(.headline); Spacer(); Text(item.scheduledAt, style: .time).font(.caption.bold()) }
                            Text(item.message).lineLimit(2)
                            Text(item.scheduledAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        let sorted = items.sorted { $0.scheduledAt < $1.scheduledAt }
                        let ids = offsets.map { sorted[$0].id }
                        items.removeAll { ids.contains($0.id) }
                        save()
                    }
                }
            }
        }
        .navigationTitle("Messaggi")
        .toolbar { Button { showingAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showingAdd) { AddScheduledMessageSheet { items.append($0); save() } }
        .onAppear(perform: load)
    }

    private func save() { if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: "idom.scheduledWhatsApp") } }
    private func load() { if let data = UserDefaults.standard.data(forKey: "idom.scheduledWhatsApp"), let decoded = try? JSONDecoder().decode([ScheduledWhatsAppMessage].self, from: data) { items = decoded } }
}

private struct AddScheduledMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var message = ""
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    let onSave: (ScheduledWhatsAppMessage) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Destinatario") { TextField("Numero con prefisso, es. +39…", text: $recipient).keyboardType(.phonePad) }
                Section("Messaggio") { TextEditor(text: $message).frame(minHeight: 110) }
                Section("Quando") { DatePicker("Data e ora", selection: $scheduledAt, in: Date()...) }
            }
            .navigationTitle("Programma")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Programma") { onSave(.init(recipient: recipient, message: message, scheduledAt: scheduledAt)); dismiss() }
                        .disabled(recipient.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
