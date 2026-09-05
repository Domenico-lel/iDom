import SwiftUI

struct SpendView: View {
    @StateObject private var store = LocalStore<Expense>(key: "idom.expenses")
    @State private var month = Date()
    @State private var allDates = false
    @State private var category = "Tutte"
    @State private var editor: Expense?
    @State private var deleting: Expense?
    private var results: [Expense] { Expense.filtered(store.items, month: allDates ? nil : month, category: category == "Tutte" ? nil : category) }
    private var categories: [String] { Array(Set(Expense.categories + store.items.map(\.category))).sorted() }
    var body: some View {
        List {
            if !store.isReadable { StorageErrorBanner() }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(allDates ? "Totale registrato" : month.formatted(.dateTime.month(.wide).year())).font(.subheadline).foregroundStyle(.secondary)
                    Text(Expense.total(results), format: .currency(code: "EUR")).font(.largeTitle.bold()).accessibilityIdentifier("spend.total")
                    Text("\(results.count) movimenti · \(category)").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
                Toggle("Tutto lo storico", isOn: $allDates)
                if !allDates {
                    HStack {
                        Button("Mese precedente", systemImage: "chevron.left") { moveMonth(-1) }.labelStyle(.iconOnly)
                        Spacer()
                        Text(month.formatted(.dateTime.month(.abbreviated).year())).font(.headline)
                        Spacer()
                        Button("Mese successivo", systemImage: "chevron.right") { moveMonth(1) }.labelStyle(.iconOnly)
                    }.buttonStyle(.borderless)
                }
                Picker("Categoria", selection: $category) {
                    Text("Tutte").tag("Tutte")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
            }
            if results.contains(where: { !$0.hasValidAmount }) {
                Label("Alcuni vecchi importi non sono validi e sono esclusi dai totali. Tocca i movimenti indicati per correggerli.", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.red)
            }
            if !results.isEmpty {
                Section("Per categoria") {
                    ForEach(categories.filter { c in results.contains { $0.category == c } }, id: \.self) { c in
                        LabeledContent(c) { Text(Expense.total(results.filter { $0.category == c }), format: .currency(code: "EUR")) }
                    }
                }
            }
            Section("Movimenti · Tocca per modificare") {
                if results.isEmpty && store.isReadable {
                    ContentUnavailableView(store.items.isEmpty ? "Nessuna spesa" : "Nessun movimento nel filtro", systemImage: "eurosign.circle", description: Text(store.items.isEmpty ? "Registra la prima spesa con il pulsante +." : "Cambia mese, categoria oppure mostra tutto lo storico."))
                }
                ForEach(results) { expense in
                    Button { editor = expense } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.title).font(.headline).foregroundStyle(.primary)
                                Text("\(expense.category) · \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if expense.hasValidAmount {
                                Text(expense.amount, format: .currency(code: "EUR")).fontWeight(.semibold).foregroundStyle(.primary)
                            } else {
                                Text("Da correggere").font(.caption).foregroundStyle(.red)
                            }
                        }.padding(.vertical, 4)
                    }
                    .swipeActions(allowsFullSwipe: false) { Button("Elimina", role: .destructive) { deleting = expense } }
                }
            }
        }
        .navigationTitle("Spend")
        .toolbar {
            Button("Aggiungi spesa", systemImage: "plus") { editor = Expense(title: "", amount: 0, category: category == "Tutte" ? "Altro" : category) }
                .disabled(!store.isReadable)
        }
        .sheet(item: $editor) { expense in
            ExpenseEditor(item: expense, isNew: !store.items.contains { $0.id == expense.id }) { value in
                guard store.upsert(value) else { return false }
                month = value.date
                category = "Tutte"
                return true
            }
        }
        .alert("Eliminare questa spesa?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Elimina", role: .destructive) { if let item = deleting { store.remove(id: item.id) }; deleting = nil }
            Button("Annulla", role: .cancel) { deleting = nil }
        } message: { Text(deleting?.title ?? "") }
        .storageAlert($store.issue)
    }
    private func moveMonth(_ offset: Int) {
        let start = Calendar.current.dateInterval(of: .month, for: month)?.start ?? month
        month = Calendar.current.date(byAdding: .month, value: offset, to: start) ?? month
    }
}

private struct ExpenseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: Expense
    @State private var amount: String
    @State private var failed = false
    let isNew: Bool
    let onSave: (Expense) -> Bool
    init(item: Expense, isNew: Bool, onSave: @escaping (Expense) -> Bool) {
        _item = State(initialValue: item)
        _amount = State(initialValue: isNew ? "" : String(format: "%.2f", item.amount).replacingOccurrences(of: ".", with: ","))
        self.isNew = isNew
        self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Descrizione", text: $item.title).accessibilityIdentifier("expense.title")
                Section {
                    TextField("Importo in euro", text: $amount).keyboardType(.decimalPad).accessibilityIdentifier("expense.amount")
                } footer: {
                    Text(amount.isEmpty || Expense.parseAmount(amount) != nil ? "Euro, fino a due decimali. Esempio: 12,50." : "Inserisci un importo maggiore di zero, fino a 999.999.999,99 €, senza separatori delle migliaia.")
                        .foregroundStyle(!amount.isEmpty && Expense.parseAmount(amount) == nil ? Color.red : Color.secondary)
                }
                Picker("Categoria", selection: $item.category) {
                    ForEach(Array(Set(Expense.categories + [item.category])).sorted(), id: \.self) { Text($0).tag($0) }
                }
                DatePicker("Data", selection: $item.date, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle(isNew ? "Nuova spesa" : "Modifica spesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let value = Expense.parseAmount(amount) else { return }
                        item.amount = value
                        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if onSave(item) { dismiss() } else { failed = true }
                    }.disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Expense.parseAmount(amount) == nil)
                }
            }
            .alert("Salvataggio non riuscito", isPresented: $failed) { Button("OK", role: .cancel) { } }
        }
    }
}
