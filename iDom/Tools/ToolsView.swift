import SwiftUI

struct ToolsView: View {
    var body: some View {
        List(ModuleCatalog.modules) { module in
            NavigationLink(value: module) {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(module.title).font(.headline)
                        Text(module.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: module.symbol)
                        .foregroundStyle(module.tint)
                        .frame(width: 30)
                }
                .padding(.vertical, 5)
            }
        }
        .navigationTitle("Tools")
        .navigationDestination(for: iDomModule.self) { module in
            ModulePlaceholderView(module: module)
        }
    }
}
