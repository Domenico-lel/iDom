import SwiftUI

@main
struct iDomApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let reminders = DeadlineReminders.shared
    var body: some Scene {
        WindowGroup {
            RootView()
                .task { await reminders.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await reminders.refresh() } }
                }
        }
    }
}
