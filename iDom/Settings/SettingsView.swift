import SwiftUI

struct SettingsView: View {
    @AppStorage("haptics") private var haptics = true

    var body: some View {
        Form {
            Section("iDom") {
                LabeledContent("Versione", value: "0.1.0")
                LabeledContent("Moduli", value: "5")
            }

            Section("Esperienza") {
                Toggle("Feedback aptico", isOn: $haptics)
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
