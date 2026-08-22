import SwiftUI

@main
struct RemoteMeetingMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
