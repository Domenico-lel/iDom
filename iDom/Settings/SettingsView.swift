import SwiftUI

struct SettingsView: View {
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Form {
            Section("iDom") {
                LabeledContent("Versione", value: "0.2.0")
                LabeledContent("Moduli", value: "5")
            }

            Section("Esperienza") {
                Toggle("Feedback aptico", isOn: $haptics)
            }

            Section("Novità 0.2") {
                Label("Quick Copy funzionante", systemImage: "doc.on.doc.fill")
                Label("Parcheggio con posizione e Apple Maps", systemImage: "car.fill")
                Label("Scadenze salvate sul dispositivo", systemImage: "calendar.badge.clock")
            }

            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "house.and.flag.fill").font(.title2)
                        Text("iDom").font(.headline)
                        Text("Il tuo spazio personale su iPhone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Impostazioni")
    }
}
