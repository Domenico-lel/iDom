import SwiftUI

struct ScheduledMessagesView: View {
    @StateObject private var model = WhatsAppViewModel()
    @State private var showingSetup = false
    @State private var draft: WhatsAppDraft?
    @State private var cancelling: WhatsAppJob?
    @State private var removing = false
    @State private var showingDrafts = false
    @State private var reusedDraft: WhatsAppDraft?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Label("WhatsApp dal tuo PC", systemImage: "desktopcomputer")
                    .font(.headline)
                Text("Scegli testo e orario: il PC invia anche con iDom chiusa. Deve essere acceso, connesso e con il tuo utente già entrato in Windows; lo schermo può essere bloccato.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !model.readable { Section { StorageErrorBanner() } }
            if model.endpoint == nil {
                Section {
                    Button("Collega WhatsApp sul PC") { showingSetup = true }
                        .accessibilityIdentifier("whatsapp.configure").disabled(!model.readable)
                    Text("Installa il componente iDom WhatsApp sul PC e collega il tuo account personale tramite QR. Il collegamento è distinto da PC Remote.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Section("Collegamento") {
                    Label(connectionTitle, systemImage: model.reachable && model.status?.connection == "ready" ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(model.reachable && model.status?.connection == "ready" ? Color.green : Color.orange)
                    if let account = model.status?.account { Text("Account collegato: +\(account)").font(.caption) }
                    if model.status?.simulated == true { Label("Simulazione: nessun messaggio verrà inviato", systemImage: "testtube.2").foregroundStyle(.orange) }
                    if let problem = model.status?.error ?? model.connectionMessage { Text(problem).font(.footnote).foregroundStyle(.orange) }
                    Button("Aggiorna stato") { Task { await model.refresh() } }.disabled(model.busy)
                }
                if let pending = model.pending {
                    Section("Conferma da verificare") {
                        Text("La richiesta per +\(pending.request.recipient) è conservata. Aggiorna lo stato o riprova la stessa richiesta: il PC riconosce l’identificativo ed evita di programmarla due volte.").font(.footnote)
                        Button("Riprova stessa richiesta") { Task { await model.retryPending() } }.disabled(model.busy)
                    }
                }
                Section {
                    Button { draft = WhatsAppDraft() } label: { Label("Programma un messaggio", systemImage: "plus.message") }
                        .accessibilityIdentifier("whatsapp.new").disabled(!model.canSchedule)
                    Text("Se PC o WhatsApp sono offline, il programma attende al massimo 5 minuti. Dopo segna il messaggio come non inviato. Gli esiti incerti non vengono ritentati automaticamente.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section(model.reachable ? "Messaggi sul PC" : "Ultimo stato ricevuto · da aggiornare") {
                    if model.status?.jobs.isEmpty != false { Text("Nessun messaggio programmato.").foregroundStyle(.secondary) }
                    ForEach(model.status?.jobs ?? []) { job in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text("+" + job.recipient).font(.headline); Spacer(); Text(job.title).font(.caption).foregroundStyle(job.state == "queued" ? Color.blue : Color.secondary) }
                            Text(job.message).textSelection(.enabled)
                            Text(job.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            if let detail = job.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                            if job.state == "queued" { Button("Annulla programmazione", role: .destructive) { cancelling = job }.disabled(!model.reachable || model.busy) }
                        }.padding(.vertical, 4)
                    }
                }
                Section {
                    Button("Modifica collegamento") { showingSetup = true }.disabled(model.busy)
                    Button("Rimuovi collegamento", role: .destructive) { removing = true }.disabled(model.pending != nil || model.busy)
                }
            }
            Section {
                Button("Bozze locali delle versioni precedenti") { showingDrafts = true }
                Text("Automazione non ufficiale di WhatsApp Web: può interrompersi con gli aggiornamenti e comporta un rischio di blocco dell’account. Sessione e coda restano sul tuo PC.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Messaggi WhatsApp")
        .sheet(isPresented: $showingSetup) { WhatsAppSetupSheet(model: model) }
        .sheet(item: $draft) { item in WhatsAppEditor(item: item, simulated: model.status?.simulated == true) { await model.schedule($0) } }
        .sheet(isPresented: $showingDrafts, onDismiss: {
            if let item = reusedDraft { draft = item; reusedDraft = nil }
        }) { WhatsAppLegacyDrafts { item in
            // Existing local drafts never become automatic sends without a new confirmation.
            reusedDraft = WhatsAppDraft(recipient: item.recipient, message: item.message)
            showingDrafts = false
        }.environmentObject(model) }
        .alert("Annullare il messaggio?", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } })) {
            Button("Annulla invio", role: .destructive) { if let job = cancelling { Task { await model.cancel(job) } }; cancelling = nil }
            Button("Indietro", role: .cancel) { cancelling = nil }
        } message: { Text("L’annullamento richiede una conferma dal PC ed è possibile solo prima che inizi l’invio.") }
        .alert("Rimuovere il collegamento?", isPresented: $removing) {
            Button("Rimuovi", role: .destructive) { model.removeConnection() }
            Button("Indietro", role: .cancel) {}
        } message: { Text("I messaggi già programmati continueranno a partire dal PC. Annullali prima se vuoi fermarli. La sessione WhatsApp sul PC resta collegata.") }
        .storageAlert(Binding(get: { showingSetup ? nil : model.issue }, set: { model.issue = $0 }))
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }
    private var connectionTitle: String {
        guard model.reachable else { return "PC non raggiungibile" }
        switch model.status?.connection {
        case "ready": return model.status?.error == nil ? "WhatsApp pronto" : "Invii sospesi"
        case "pairing": return "Scansiona il QR sul PC"
        case "starting": return "WhatsApp si sta avviando"
        default: return "WhatsApp scollegato: controlla il PC"
        }
    }
}

private struct WhatsAppSetupSheet: View {
    @ObservedObject var model: WhatsAppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = WhatsAppEndpoint()
    var body: some View {
        NavigationStack {
            Form {
                Section("Componente WhatsApp sul PC") {
                    TextField("https://pc.nome-rete.ts.net:8444", text: $endpoint.address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("whatsapp.address").disabled(model.pending != nil)
                    SecureField("Chiave WhatsApp di 64 caratteri", text: $endpoint.token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("whatsapp.token")
                }
                Section {
                    Text("Usa l’indirizzo e la chiave mostrati da Installa-WhatsApp.ps1. La porta 8444 e la chiave sono diverse da quelle di PC Remote. Salva verifica il collegamento prima di memorizzarlo.")
                    Text("Le credenziali restano nel portachiavi di questo iPhone. Il tuo account WhatsApp rimane personale.")
                }.font(.footnote)
                if model.busy { ProgressView("Verifica collegamento…") }
            }
            .navigationTitle("Collega WhatsApp")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(model.busy) }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") {
                    endpoint.address = endpoint.address.trimmingCharacters(in: .whitespacesAndNewlines)
                    endpoint.token = endpoint.token.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { if await model.configure(endpoint) { dismiss() } }
                }.disabled(!endpoint.isValid || model.busy) }
            }
            .onAppear { endpoint = model.endpoint ?? WhatsAppEndpoint() }
            .storageAlert($model.issue)
            .interactiveDismissDisabled(model.busy)
        }
    }
}

private struct WhatsAppEditor: View {
    @State var item: WhatsAppDraft
    let simulated: Bool
    let submit: (WhatsAppDraft) async -> Bool
    @State private var sending = false
    @State private var confirm = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Destinatario") {
                    TextField("Numero completo, es. +39…", text: $item.recipient).keyboardType(.phonePad).accessibilityIdentifier("whatsapp.recipient")
                    Text("Inserisci il prefisso internazionale. Prima prova con il tuo numero.").font(.caption)
                }
                Section("Testo") { TextEditor(text: $item.message).frame(minHeight: 120).accessibilityIdentifier("whatsapp.message"); Text("\(item.message.utf16.count)/4096").font(.caption) }
                Section("Quando") { DatePicker("Data e ora", selection: $item.scheduledAt, in: Date().addingTimeInterval(15)...Date().addingTimeInterval(365 * 86400)) }
                Section { Text(simulated ? "Modalità simulazione: il PC non invierà il messaggio." : "Il PC invierà automaticamente a questo numero, anche con iDom chiusa. Controlla destinatario, testo e orario.").font(.footnote) }
            }.disabled(sending)
            .navigationTitle("Programma messaggio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Indietro") { dismiss() }.disabled(sending) }
                ToolbarItem(placement: .confirmationAction) { Button("Programma") { confirm = true }.disabled(!item.isValid || sending) }
            }
            .confirmationDialog("Confermi l’invio a +\(WhatsAppDraft.phone(item.recipient) ?? item.recipient) il \(item.scheduledAt.formatted(date: .abbreviated, time: .shortened))?", isPresented: $confirm, titleVisibility: .visible) {
                Button(simulated ? "Programma simulazione" : "Programma invio automatico") { sending = true; Task { if await submit(item) { dismiss() }; sending = false } }
            }
            .interactiveDismissDisabled(sending)
        }
    }
}

private struct WhatsAppLegacyDrafts: View {
    @StateObject private var store = LocalStore<WhatsAppDraft>(key: "idom.scheduledWhatsApp")
    @EnvironmentObject private var model: WhatsAppViewModel
    @Environment(\.dismiss) private var dismiss
    let reuse: (WhatsAppDraft) -> Void
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Queste bozze non sono state inviate né programmate sul PC. Scegli una bozza per impostare un nuovo orario e confermare l’invio.").font(.footnote) }
                if !store.isReadable { StorageErrorBanner() }
                if store.items.isEmpty { Text("Nessuna bozza locale.").foregroundStyle(.secondary) }
                ForEach(store.items) { item in
                    VStack(alignment: .leading) {
                        Text(item.recipient).font(.headline)
                        Text(item.message).textSelection(.enabled)
                        Button("Usa come nuovo messaggio") { reuse(item) }.disabled(!model.canSchedule)
                    }
                }
            }.navigationTitle("Bozze locali")
                .toolbar { Button("Chiudi") { dismiss() } }
                .storageAlert($store.issue)
        }
    }
}
