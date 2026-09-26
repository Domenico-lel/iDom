import SwiftUI
import CryptoKit
import Network
import UniformTypeIdentifiers

struct NerdLabView: View {
    @State private var selection: NerdTool = .dashboard

    var body: some View {
        List {
            Section("Laboratorio") {
                ForEach(NerdTool.allCases) { tool in
                    Button {
                        selection = tool
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(tool.title)
                                Text(tool.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: tool.symbol).foregroundStyle(tool.tint)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Nerd Lab")
        .navigationDestination(for: NerdTool.self) { tool in
            NerdToolView(tool: tool)
        }
        .overlay {
            NavigationLink(value: selection) { EmptyView() }.opacity(0)
        }
        .onAppear {
            selection = .dashboard
        }
    }
}

enum NerdTool: String, CaseIterable, Identifiable, Hashable {
    case dashboard, hash, encoding, json, http, network, ipa, device, uuid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .hash: "Hash Lab"
        case .encoding: "Encoding"
        case .json: "JSON Formatter"
        case .http: "HTTP Client"
        case .network: "Network Tools"
        case .ipa: "IPA Inspector"
        case .device: "Device Info"
        case .uuid: "UUID Generator"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: "Panoramica del laboratorio"
        case .hash: "SHA-256, SHA-512 e MD5-like tools"
        case .encoding: "Base64, Hex e URL encoding"
        case .json: "Formatta e valida JSON"
        case .http: "Richieste HTTP e headers"
        case .network: "Test TCP e DNS"
        case .ipa: "Esplora metadati e struttura IPA"
        case .device: "Informazioni disponibili all'app"
        case .uuid: "Identificatori per i tuoi test"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .hash: "number"
        case .encoding: "character.cursor.ibeam"
        case .json: "curlybraces"
        case .http: "arrow.up.arrow.down"
        case .network: "network"
        case .ipa: "shippingbox"
        case .device: "iphone"
        case .uuid: "dice"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard: .blue
        case .hash: .purple
        case .encoding: .orange
        case .json: .yellow
        case .http: .green
        case .network: .cyan
        case .ipa: .pink
        case .device: .indigo
        case .uuid: .mint
        }
    }
}

@ViewBuilder
private func NerdToolView(tool: NerdTool) -> some View {
    switch tool {
    case .dashboard:
        NerdDashboardView()
    case .hash:
        NerdHashView()
    case .encoding:
        NerdEncodingView()
    case .json:
        NerdJSONView()
    case .http:
        NerdHTTPView()
    case .network:
        NerdNetworkView()
    case .ipa:
        NerdIPAView()
    case .device:
        NerdDeviceView()
    case .uuid:
        NerdUUIDView()
    }
}

struct NerdDashboardView: View {
    var body: some View {
        List {
            Section {
                Label("Toolbox locale", systemImage: "hammer.fill")
                Text("iDom Nerd Lab raccoglie strumenti per sviluppo, debugging e analisi dei tuoi progetti. I dati restano nel sandbox dell'app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Disponibile") {
                Label("Hash e encoding", systemImage: "number")
                Label("JSON e HTTP", systemImage: "curlybraces")
                Label("Test di rete", systemImage: "network")
                Label("Analisi IPA", systemImage: "shippingbox")
                Label("Info dispositivo", systemImage: "iphone")
            }
            Section("Sandbox iOS") {
                Text("iOS non permette a una normale app di eseguire comandi di shell arbitrari o accedere al filesystem di sistema. Il laboratorio usa quindi solo API consentite dal sandbox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Dashboard")
    }
}

struct NerdHashView: View {
    @State private var input = ""
    @State private var algorithm = "SHA-256"

    var digest: String {
        let data = Data(input.utf8)
        switch algorithm {
        case "SHA-512": return SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
        default: return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    var body: some View {
        Form {
            Section("Input") {
                TextEditor(text: $input).frame(minHeight: 120)
            }
            Section("Algoritmo") {
                Picker("Algoritmo", selection: $algorithm) {
                    Text("SHA-256").tag("SHA-256")
                    Text("SHA-512").tag("SHA-512")
                }
                .pickerStyle(.segmented)
            }
            Section("Digest") {
                Text(digest).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                Button("Copia") { UIPasteboard.general.string = digest }
            }
        }
        .navigationTitle("Hash Lab")
    }
}

struct NerdEncodingView: View {
    @State private var input = ""
    @State private var mode = "Base64"
    @State private var decoded = false

    var output: String {
        if mode == "Base64" {
            if decoded {
                return Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { String(data: $0, encoding: .utf8) } ?? "Base64 non valido"
            }
            return Data(input.utf8).base64EncodedString()
        }
        if decoded {
            let bytes = input.split(separator: " ").compactMap { UInt8($0, radix: 16) }
            return String(data: Data(bytes), encoding: .utf8) ?? "Hex non valido"
        }
        return input.utf8.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    var body: some View {
        Form {
            Picker("Formato", selection: $mode) {
                Text("Base64").tag("Base64")
                Text("Hex").tag("Hex")
            }.pickerStyle(.segmented)
            Toggle("Decodifica", isOn: $decoded)
            TextEditor(text: $input).frame(minHeight: 150)
            Section("Risultato") {
                Text(output).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                Button("Copia") { UIPasteboard.general.string = output }
            }
        }
        .navigationTitle("Encoding")
    }
}

struct NerdJSONView: View {
    @State private var input = "{\"hello\":\"world\"}"
    @State private var output = ""

    var body: some View {
        Form {
            TextEditor(text: $input).font(.system(.body, design: .monospaced)).frame(minHeight: 220)
            Button("Formatta e valida") {
                do {
                    let object = try JSONSerialization.jsonObject(with: Data(input.utf8))
                    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
                    output = String(data: data, encoding: .utf8) ?? ""
                } catch {
                    output = "JSON non valido: \(error.localizedDescription)"
                }
            }
            Section("Output") {
                Text(output).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                Button("Copia") { UIPasteboard.general.string = output }
            }
        }
        .navigationTitle("JSON Formatter")
    }
}

struct NerdHTTPView: View {
    @State private var urlText = "https://example.com"
    @State private var method = "GET"
    @State private var result = ""
    @State private var busy = false

    var body: some View {
        Form {
            TextField("URL", text: $urlText).textInputAutocapitalization(.never).keyboardType(.URL)
            Picker("Metodo", selection: $method) {
                Text("GET").tag("GET")
                Text("HEAD").tag("HEAD")
            }.pickerStyle(.segmented)
            Button(busy ? "Richiesta…" : "Invia richiesta") {
                Task { await request() }
            }
            .disabled(busy)
            Section("Risposta") {
                ScrollView { Text(result.isEmpty ? "Nessun risultato" : result).font(.system(.footnote, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
            }
        }
        .navigationTitle("HTTP Client")
    }

    private func request() async {
        guard let url = URL(string: urlText) else { result = "URL non valido"; return }
        busy = true
        defer { busy = false }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        do {
            let started = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Int(Date().timeIntervalSince(started) * 1000)
            if let http = response as? HTTPURLResponse {
                var text = "HTTP \(http.statusCode) • \(elapsed) ms\n"
                text += "URL: \(http.url?.absoluteString ?? url.absoluteString)\n\n"
                for (key, value) in http.allHeaderFields.sorted(by: { String(describing: $0.key) < String(describing: $1.key) }) {
                    text += "\(key): \(value)\n"
                }
                text += "\nBody:\n\(String(data: data.prefix(200_000), encoding: .utf8) ?? "<binary>")"
                result = text
            }
        } catch {
            result = "Errore: \(error.localizedDescription)"
        }
    }
}

struct NerdNetworkView: View {
    @State private var host = "example.com"
    @State private var port = "443"
    @State private var result = ""
    @State private var busy = false

    var body: some View {
        Form {
            TextField("Host", text: $host).textInputAutocapitalization(.never)
            TextField("Porta", text: $port).keyboardType(.numberPad)
            Button(busy ? "Test…" : "Test TCP") {
                Task { await test() }
            }.disabled(busy)
            Section("Risultato") { Text(result.isEmpty ? "Nessun test eseguito" : result).font(.system(.footnote, design: .monospaced)) }
            Section("Nota") {
                Text("Usalo sui tuoi dispositivi e sulle reti che amministri.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Network Tools")
    }

    private func test() async {
        guard let portValue = UInt16(port) else { result = "Porta non valida"; return }
        busy = true
        defer { busy = false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: portValue)!, using: .tcp)
        result = await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume(returning: "TCP OPEN — \(host):\(portValue)")
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(returning: "TCP FAILED — \(error.localizedDescription)")
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }
}

struct NerdDeviceView: View {
    private var model: String { UIDevice.current.modelIdentifier }
    private var system: String { UIDevice.current.systemName + " " + UIDevice.current.systemVersion }

    var body: some View {
        Form {
            Section("Dispositivo") {
                LabeledContent("Modello", value: model)
                LabeledContent("Nome", value: UIDevice.current.name)
                LabeledContent("Sistema", value: system)
                LabeledContent("Architettura", value: "arm64e")
            }
            Section("App") {
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "-")
                LabeledContent("Versione", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
            }
        }
        .navigationTitle("Device Info")
    }
}

struct NerdUUIDView: View {
    @State private var value = UUID().uuidString

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "dice").font(.system(size: 48)).foregroundStyle(.mint)
            Text(value).font(.system(.body, design: .monospaced)).multilineTextAlignment(.center).textSelection(.enabled).padding()
            Button("Genera UUID") { value = UUID().uuidString }
            Button("Copia") { UIPasteboard.general.string = value }
        }
        .padding()
        .navigationTitle("UUID Generator")
    }
}

struct NerdIPAView: View {
    @State private var showImporter = false
    @State private var report = "Importa un file .ipa per analizzarne il contenitore ZIP e i metadati disponibili."
    @State private var fileName = ""

    var body: some View {
        Form {
            Button("Importa IPA") { showImporter = true }
            if !fileName.isEmpty {
                Section("File") { Text(fileName).font(.system(.footnote, design: .monospaced)) }
            }
            Section("Analisi") {
                ScrollView { Text(report).font(.system(.footnote, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
            }
            Section("Limiti") {
                Text("L'app non modifica la firma, non aggira DRM e non accede al filesystem di sistema. L'analisi è pensata per IPA tuoi o che hai diritto di esaminare.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("IPA Inspector")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                analyze(url)
            case .failure(let error):
                report = "Importazione fallita: \(error.localizedDescription)"
            }
        }
    }

    private func analyze(_ url: URL) {
        fileName = url.lastPathComponent
        guard url.startAccessingSecurityScopedResource() else {
            report = "Accesso al file negato."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            var text = "Dimensione: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))\n"
            text += "SHA-256: \(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())\n"
            text += "ZIP signature: \(data.prefix(2).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            if let marker = data.range(of: Data("Payload/".utf8)) {
                text += "Payload/ trovato nel contenitore.\n"
                text += "Offset prima occorrenza: \(marker.lowerBound)\n"
            } else {
                text += "Attenzione: Payload/ non trovato.\n"
            }
            report = text
        } catch {
            report = "Lettura fallita: \(error.localizedDescription)"
        }
    }
}
