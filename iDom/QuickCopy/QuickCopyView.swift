import SwiftUI

struct QuickCopyView: View {
    @StateObject private var store = LocalStore<QuickCopyItem>.quickCopy()
    @AppStorage("haptics") private var haptics = true
    @State private var query = ""
    @State private var editor: QuickCopyItem?
    @State private var deleting: QuickCopyItem?
    @State private var copiedID: UUID?
    private var results: [QuickCopyItem] {
        store.items.filter { query.isEmpty || $0.title.localizedStandardContains(query) || $0.value.localizedStandardContains(query) }
    }

    var body: some View {
        List {
            if !store.isReadable { StorageErrorBanner() }
            if store.items.isEmpty && store.isReadable {
                ContentUnavailableView("I tuoi testi, a portata di tap", systemImage: "doc.on.doc", description: Text("Aggiungi indirizzi, email e messaggi che usi spesso con il pulsante +."))
            } else if results.isEmpty && store.isReadable {
                ContentUnavailableView.search(text: query)
            } else {
                Section {
                    ForEach(results) { item in
                        Button {
                            UIPasteboard.general.string = item.value
                            copiedID = item.id
                            if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: copiedID == item.id ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                    .foregroundStyle(copiedID == item.id ? .green : .indigo)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.headline).foregroundStyle(.primary)
                                    Text(item.value).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                                }
                                Spacer(minLength: 0)
                            }.padding(.vertical, 5)
                        }
                        .accessibilityLabel("Copia \(item.title)")
                        .accessibilityValue(copiedID == item.id ? "Copiato" : item.value)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Elimina", role: .destructive) { deleting = item }
                            Button("Modifica") { editor = item }.tint(.indigo)
                        }
                        .contextMenu {
                            Button("Modifica", systemImage: "pencil") { editor = item }
                            ShareLink(item: item.value)
                            Button("Elimina", systemImage: "trash", role: .destructive) { deleting = item }
                        }
                    }
                } header: { Text(copiedID == nil ? "Tocca per copiare · Scorri per modificare" : "Copiato negli appunti") }
            }
        }
        .navigationTitle("Quick Copy")
        .searchable(text: $query, prompt: "Cerca nei testi")
        .toolbar {
            Button("Aggiungi testo", systemImage: "plus") { editor = QuickCopyItem(title: "", value: "") }
                .disabled(!store.isReadable)
        }
        .sheet(item: $editor) { item in
            QuickCopyEditor(item: item, isNew: !store.items.contains { $0.id == item.id }) { value in
                copiedID = nil
                guard store.upsert(value) else { return false }
                query = ""
                return true
            }
        }
        .alert("Eliminare questo testo?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Elimina", role: .destructive) { if let item = deleting { store.remove(id: item.id); copiedID = nil }; deleting = nil }
            Button("Annulla", role: .cancel) { deleting = nil }
        } message: { Text(deleting?.title ?? "") }
        .storageAlert($store.issue)
        .task(id: copiedID) {
            guard copiedID != nil else { return }
            do { try await Task.sleep(for: .seconds(2)); copiedID = nil } catch { }
        }
    }
}

private struct QuickCopyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: QuickCopyItem
    let isNew: Bool
    let onSave: (QuickCopyItem) -> Bool
    @State private var failed = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $item.title).accessibilityIdentifier("copy.title")
                TextField("Testo da copiare", text: $item.value, axis: .vertical)
                    .lineLimit(5...12).accessibilityIdentifier("copy.value")
            }
            .navigationTitle(isNew ? "Nuovo testo" : "Modifica testo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if onSave(item) { dismiss() } else { failed = true }
                    }.disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || item.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Salvataggio non riuscito", isPresented: $failed) { Button("OK", role: .cancel) { } }
        }
    }
}
