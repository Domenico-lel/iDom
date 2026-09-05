import SwiftUI

private struct Expense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var category: String
    var date = Date()
}

struct SpendView: View {
    @State private var expenses: [Expense] = []
    @State private var showingAdd = false

    private var total: Double { expenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spese registrate").font(.caption).foregroundStyle(.secondary)
                    Text(total, format: .currency(code: "EUR")).font(.largeTitle.bold())
                }.padding(.vertical, 8)
            }

            Section("Movimenti") {
                if expenses.isEmpty {
                    ContentUnavailableView("Nessuna spesa", systemImage: "eurosign.circle", description: Text("Registra una spesa in pochi secondi."))
                } else {
                    ForEach(expenses.sorted { $0.date > $1.date }) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(expense.title).font(.headline)
                                Text("\(expense.category) · \(expense.date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(expense.amount, format: .currency(code: "EUR")).fontWeight(.semibold)
                        }.padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        let sorted = expenses.sorted { $0.date > $1.date }
                        let ids = offsets.map { sorted[$0].id }
                        expenses.removeAll { ids.contains($0.id) }
                        save()
                    }
                }
            }
        }
        .navigationTitle("Spend")
        .toolbar { Button { showingAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showingAdd) { AddExpenseSheet { expenses.append($0); save() } }
        .onAppear(perform: load)
    }

    private func save() { if let data = try? JSONEncoder().encode(expenses) { UserDefaults.standard.set(data, forKey: "idom.expenses") } }
    private func load() { if let data = UserDefaults.standard.data(forKey: "idom.expenses"), let value = try? JSONDecoder().decode([Expense].self, from: data) { expenses = value } }
}

private struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amount = ""
    @State private var category = "Altro"
    let onSave: (Expense) -> Void
    private let categories = ["Cibo", "Auto", "Casa", "Svago", "Tech", "Altro"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Descrizione", text: $title)
                TextField("Importo", text: $amount).keyboardType(.decimalPad)
                Picker("Categoria", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }
            }
            .navigationTitle("Nuova spesa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        let normalized = amount.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(normalized) { onSave(.init(title: title, amount: value, category: category)); dismiss() }
                    }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amount.isEmpty)
                }
            }
        }
    }
}
