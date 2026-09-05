import SwiftUI

private struct DeadlineItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var symbol: String
}

struct DeadlinesView: View {
    @State private var items: [DeadlineItem] = []
    @State private var showingAdd = false

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView("Nessuna scadenza", systemImage: "calendar.badge.checkmark", description: Text("Aggiungi patente, assicurazione, bollo o qualsiasi cosa tu non voglia dimenticare."))
            } else {
                ForEach(items.sorted { $0.date < $1.date }) { item in
                    HStack(spacing: 14) {
                        Image(systemName: item.symbol).foregroundStyle(.red).frame(width: 32)
                        VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            Text(item.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(daysText(to: item.date)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }
                .onDelete { indexSet in
                    let sorted = items.sorted { $0.date < $1.date }
                    let ids = indexSet.map { sorted[$0].id }
                    items.removeAll { ids.contains($0.id) }
                    save()
                }
            }
        }
        .navigationTitle("Scadenze")
        .toolbar { Button { showingAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showingAdd) { AddDeadlineSheet { item in items.append(item); save() } }
        .onAppear(perform: load)
    }

    private func daysText(to date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return "Scaduta" }
        if days == 0 { return "Oggi" }
        return "\(days) gg"
    }

    private func save() { if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: "idom.deadlines") } }
    private func load() { if let data = UserDefaults.standard.data(forKey: "idom.deadlines"), let decoded = try? JSONDecoder().decode([DeadlineItem].self, from: data) { items = decoded } }
}

private struct AddDeadlineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    let onSave: (DeadlineItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $title)
                DatePicker("Data", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("Nuova scadenza")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") { onSave(.init(title: title, date: date, symbol: "calendar")); dismiss() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }
}
