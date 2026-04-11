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

        // macOS Settings scene. SwiftUI wires this up to the standard
        // "HermesMac → Instellingen…" menu item and the Cmd+, shortcut
        // automatically, so we don't need a custom CommandGroup for it.
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(AppSettings.shared)
        }
        #endif
    }
}
