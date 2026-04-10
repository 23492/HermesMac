import SwiftUI
import SwiftData

/// Main entry point for the HermesMac application.
@main
struct HermesMacApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(ModelStack.shared)
                .environment(AppSettings.shared)
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 700)
        .commands {
            HermesMacCommands()
        }
        #endif
    }
}
