import SwiftUI

@MainActor
final class PCRemoteModel: ObservableObject {
    @Published var configuration: PCRemoteConfiguration?
    @Published var status: RemoteStatus?
    @Published var connection = "Da verificare"
    @Published var message: String?
    @Published var busy = false
    @Published var loadFailed = false
    private let client = PCRemoteClient()

    init() { reload() }

    func reload() {
        do { configuration = try RemoteKeychain.read(); loadFailed = false }
        catch { loadFailed = true; message = "Configurazione non leggibile. Gli originali sono conservati. Sblocca l’iPhone e riprova." }
        status = nil
        connection = "Da verificare"
    }

    func refresh() async {
        guard let configuration, !busy, !loadFailed else { return }
        busy = true
        defer { busy = false }
        await readStatus(configuration.pc)
    }

    private func readStatus(_ endpoint: RemoteEndpoint) async {
        do {
            status = try await client.status(endpoint, role: "pc")
            connection = "PC raggiungibile"
        } catch is CancellationError { }
        catch { status = nil; connection = error.localizedDescription }
    }

    func command(_ action: String) async {
        guard let configuration, !busy, !loadFailed else { return }
        busy = true
        defer { busy = false }
        do {
            let endpoint = action == "wake" ? configuration.wake : configuration.pc
            guard action != "wake" || configuration.wakeEnabled else { return }
            // Verify the role immediately before sending a command to a saved address.
            _ = try await client.status(endpoint, role: action == "wake" ? "wake" : "pc")
            message = try await client.command(endpoint, action: action)
            await readStatus(configuration.pc)
        } catch is CancellationError { }
        catch { message = error.localizedDescription; status = nil }
    }

    func forget() {
        do { try RemoteKeychain.remove(); configuration = nil; status = nil; message = nil }
        catch { message = error.localizedDescription }
    }
}

struct PCRemoteView: View {
    @StateObject private var model = PCRemoteModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var editing = false
    @State private var confirmShutdown = false
    @State private var confirmForget = false

    var body: some View {
        Form {
            if model.loadFailed {
                Section {
                    Text(model.message ?? "Configurazione non leggibile.")
                    Button("Riprova") { model.reload() }
                }
            } else if model.configuration == nil {
                Section {
                    Label("Il tuo PC, anche fuori casa", systemImage: "desktopcomputer").font(.headline)
                    Text("Collega il componente iDom sul PC Windows e Tailscale. Potrai spegnere il PC e, con un ponte di accensione nella rete di casa, riaccenderlo.")
                    Button("Collega il PC") { editing = true }
                        .accessibilityIdentifier("pc.configure")
                }
            } else {
                Section("Collegamento") {
                    Label(model.status == nil ? "Stato non confermato" : "PC raggiungibile", systemImage: model.status == nil ? "questionmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(model.status == nil ? Color.secondary : Color.green)
                    if let status = model.status {
                        Text(status.name)
                        if status.simulated { Text("Modalità prova: nessun comando spegnerà il computer.").foregroundStyle(.orange) }
                        if let remaining = status.shutdownRemaining {
                            Text("Spegnimento programmato: circa \(remaining) secondi.")
                        }
                        if let error = status.lastError { Text(error).foregroundStyle(.red) }
                    } else { Text(model.connection).font(.footnote).foregroundStyle(.secondary) }
                    Button("Aggiorna stato") { Task { await model.refresh() } }
                        .disabled(model.busy)
                    if model.busy { ProgressView("Collegamento in corso…") }
                }
                Section {
                    Button { Task { await model.command("wake") } } label: {
                        Label("Accendi", systemImage: "power")
                    }
                    .disabled(model.busy || model.configuration?.wakeEnabled != true)
                    Button(role: .destructive) { confirmShutdown = true } label: {
                        Label("Spegni", systemImage: "power.circle")
                    }
                    .disabled(model.busy || model.status == nil || model.status?.shutdownRemaining != nil)
                    // Keep cancellation available even when the last status request timed out.
                    Button("Annulla spegnimento") { Task { await model.command("cancel") } }
                        .disabled(model.busy)
                } header: { Text("Alimentazione") } footer: {
                    Text(model.configuration?.wakeEnabled == true
                         ? "Accendi invia il segnale Wake-on-LAN. L’avvio è confermato solo quando il PC torna raggiungibile."
                         : "Per accendere un PC spento serve un ponte Wake-on-LAN acceso nella rete di casa. Configuralo in Modifica collegamento.")
                }
                if let message = model.message {
                    Section("Ultima operazione") { Text(message).accessibilityIdentifier("pc.result") }
                }
                Section {
                    Button("Modifica collegamento") { editing = true }.disabled(model.busy)
                    Button("Rimuovi collegamento", role: .destructive) { confirmForget = true }.disabled(model.busy)
                }
            }
            Section("Prima configurazione") {
                Text("Installa Tailscale su iPhone e PC, usando lo stesso account. Il componente Windows fornisce l’indirizzo HTTPS e una chiave privata da inserire qui.")
                Text("L’accensione richiede Ethernet, Wake-on-LAN abilitato nel PC e un router compatibile o un altro dispositivo acceso in casa. Il supporto da PC completamente spento dipende dall’hardware.")
                Link("Guida al collegamento", destination: URL(string: "https://github.com/Domenico-lel/iDom/blob/main/Companion/README.md")!)
            }.font(.footnote)
        }
        .navigationTitle("PC Remote")
        .sheet(isPresented: $editing) {
            PCRemoteSetupView(configuration: model.configuration ?? PCRemoteConfiguration()) { model.reload() }
        }
        .alert("Spegnere il PC?", isPresented: $confirmShutdown) {
            Button("Spegni tra 30 secondi", role: .destructive) { Task { await model.command("shutdown") } }
            Button("Indietro", role: .cancel) { }
        } message: { Text("Salva il lavoro sul PC. Puoi annullare da iDom durante il conto alla rovescia. Le applicazioni con documenti aperti potrebbero impedire lo spegnimento.") }
        .alert("Rimuovere il collegamento?", isPresented: $confirmForget) {
            Button("Rimuovi", role: .destructive) { model.forget() }
            Button("Indietro", role: .cancel) { }
        } message: { Text("Le credenziali vengono rimosse dall’iPhone. Il componente sul PC rimane installato e un eventuale spegnimento programmato continua.") }
        .task(id: "\(scenePhase == .active)-\(editing)-\(model.configuration?.pc.address ?? "")") {
            guard scenePhase == .active, !editing else { return }
            while !Task.isCancelled {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }
}

private struct PCRemoteSetupView: View {
    @State var configuration: PCRemoteConfiguration
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("PC Windows") {
                    endpointFields($configuration.pc)
                }
                Section {
                    Toggle("Ho un ponte di accensione", isOn: $configuration.wakeEnabled)
                    if configuration.wakeEnabled { endpointFields($configuration.wake) }
                } header: { Text("Accensione") } footer: {
                    Text("Il ponte esegue il componente iDom in modalità Wake-on-LAN su un altro dispositivo sempre acceso in casa. Non inserire qui l’indirizzo del PC da accendere.")
                }
                Section {
                    Text("Usa l’indirizzo https://nome.rete.ts.net:8443 mostrato dal componente. Le chiavi di 64 caratteri sono conservate nel portachiavi di questo iPhone e non vengono sincronizzate.")
                }.font(.footnote)
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Collega il PC")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        do {
                            if !configuration.wakeEnabled { configuration.wake = RemoteEndpoint() }
                            try RemoteKeychain.save(configuration)
                            onSave()
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(!configuration.isValid)
                }
            }
        }
    }

    @ViewBuilder private func endpointFields(_ endpoint: Binding<RemoteEndpoint>) -> some View {
        TextField("Indirizzo HTTPS Tailscale", text: endpoint.address)
            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        SecureField("Chiave di collegamento", text: endpoint.token)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
    }
}
