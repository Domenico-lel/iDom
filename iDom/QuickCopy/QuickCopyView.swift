import SwiftUI

struct QuickCopyView: View {
    @AppStorage("quickCopyItems") private var storedItems = "Email|example@email.com\nIndirizzo|Aggiungi il tuo indirizzo"
    @State private var showingAdd = false
    @State private var copiedID: UUID?

    private var items: [QuickCopyItem] {
        storedItems.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return QuickCopyItem(title: parts[0], value: parts[1])
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Button {
                        UIPasteboard.general.string = item.value
                        copiedID = item.id
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: copiedID == item.id ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                .font(.title3)
                                .foregroundStyle(copiedID == item.id ? .green : .indigo)
                                .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline).foregroundStyle(.primary)
                                Text(item.value).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    }
                }
            } header: {
                Text("Tocca per copiare")
            }
        }
        .navigationTitle("Quick Copy")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) {
            AddQuickCopyView(storedItems: $storedItems)
        }
    }
}

private struct QuickCopyItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct AddQuickCopyView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var storedItems: String
    @State private var title = ""
    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $title)
                TextField("Testo da copiare", text: $value, axis: .vertical)
            }
            .navigationTitle("Nuovo elemento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        let cleanTitle = title.replacingOccurrences(of: "|", with: "-").replacingOccurrences(of: "\n", with: " ")
                        let cleanValue = value.replacingOccurrences(of: "|", with: "-").replacingOccurrences(of: "\n", with: " ")
                        if !storedItems.isEmpty { storedItems += "\n" }
                        storedItems += "\(cleanTitle)|\(cleanValue)"
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || value.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
