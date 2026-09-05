import SwiftUI

struct SettingsView: View {
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Form {
            Section("iDom") {
                LabeledContent("Versione", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                LabeledContent("Strumenti completi", value: "4")
            }

            Section("Esperienza") {
                Toggle("Feedback aptico", isOn: $haptics)
            }

            Section("Disponibili") {
                Label("Quick Copy", systemImage: "doc.on.doc.fill")
                Label("Parcheggio", systemImage: "car.fill")
                Label("Scadenze", systemImage: "calendar.badge.clock")
                Label("Spend", systemImage: "eurosign.circle")
            }

            Section("Beta") {
                Label("Messaggi WhatsApp · solo programmazione", systemImage: "message")
            }

            Section("Dati") {
                Text("Testi, spese, scadenze e parcheggio sono salvati su questo iPhone. Nessuna sincronizzazione tra dispositivi. Eliminando l’app vengono eliminati anche i dati locali.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("In sviluppo") {
                Label("PC Remote — non completo", systemImage: "desktopcomputer")
                Label("Rete — non completo", systemImage: "wifi")
            }

            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "house.and.flag.fill").font(.title2)
                        Text("iDom").font(.headline)
                        Text("Il tuo spazio personale su iPhone").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Impostazioni")
    }
}
