import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { ToolsView() }
                .tabItem { Label("Tools", systemImage: "square.grid.2x2.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
    }
}
