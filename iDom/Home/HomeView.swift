import SwiftUI

struct HomeView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Buongiorno"
        case 12..<18: return "Buon pomeriggio"
        default: return "Buonasera"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting).font(.subheadline).foregroundStyle(.secondary)
                    Text("Domenico").font(.largeTitle.bold())
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Stato").font(.headline)
                    HStack {
                        Label("iDom pronto", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("Tutto ok").foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    Text("I tuoi strumenti").font(.title2.bold())
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ModuleCatalog.modules) { module in
                            NavigationLink(value: module) {
                                ModuleCard(module: module)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("iDom")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: iDomModule.self) { module in
            ModulePlaceholderView(module: module)
        }
    }
}

private struct ModuleCard: View {
    let module: iDomModule

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: module.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(module.tint)
                .frame(width: 44, height: 44)
                .background(module.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer(minLength: 4)
            Text(module.title).font(.headline).foregroundStyle(.primary)
            Text(module.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ModulePlaceholderView: View {
    let module: iDomModule

    var body: some View {
        ContentUnavailableView {
            Label(module.title, systemImage: module.symbol)
        } description: {
            Text("Questo modulo è pronto per essere sviluppato dentro iDom.")
        }
        .navigationTitle(module.title)
    }
}
