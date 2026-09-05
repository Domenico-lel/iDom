import SwiftUI

struct SettingsView: View {
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Form {
            Section("iDom") {
                LabeledContent("Versione", value: "0.2.1")
                LabeledContent("Build", value: "3")
                LabeledContent("Moduli", value: "5")
            }

            Section("Esperienza") {
                Toggle("Feedback aptico", isOn: $haptics)
            }

            Section("Disponibili") {
                Label("Quick Copy", systemImage: "doc.on.doc.fill")
                Label("Parcheggio", systemImage: "car.fill")
                Label("Scadenze", systemImage: "calendar.badge.clock")
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
