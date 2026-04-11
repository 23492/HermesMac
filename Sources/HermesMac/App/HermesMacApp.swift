import SwiftUI
import SwiftData

/// Main entry point for the HermesMac application.
///
/// The root scene delegates almost all work to ``RootView``. The only
/// extra responsibilities here are:
///
/// - Picking up ``ModelStack/shared`` (wrapped in `Result`) so a
///   corrupt on-disk store is surfaced as a recoverable error overlay
///   via ``LaunchView`` instead of crashing the process.
/// - Injecting ``AppSettings/shared`` into the SwiftUI environment so
///   every downstream view can read the Keychain-backed settings.
/// - Wiring up macOS-only scene modifiers (`.defaultSize`,
///   `.commands`, the dedicated `Settings` scene).
@main
@MainActor
struct HermesMacApp: App {

    /// Snapshot of the model container build result. Stored as
    /// `@State` so the retry button in ``LaunchView`` can trigger a
    /// rebuild and update the view hierarchy.
    ///
    /// The initial value is deferred to the struct's `init()` so we
    /// can explicitly call the MainActor-isolated ``ModelStack/shared``
    /// getter without tripping strict concurrency checks on property
    /// initializers.
    @State private var containerResult: Result<ModelContainer, Error>

    init() {
        _containerResult = State(initialValue: ModelStack.shared)
    }

    var body: some Scene {
        mainWindow
        #if os(macOS)
        // macOS Settings scene. SwiftUI wires this up to the standard
        // "HermesMac → Instellingen…" menu item and the Cmd+, shortcut
        // automatically, so we don't need a custom CommandGroup for it.
        //
        // We preemptively attach the on-disk container if the root
        // container build succeeded so SettingsView can make SwiftData
        // queries if we ever need them. When the build failed the user
        // should be looking at the LaunchView error overlay anyway, so
        // the Settings scene is not a meaningful target.
        Settings {
            SettingsView()
                .environment(AppSettings.shared)
                .modelContainer(settingsContainer)
        }
        #endif
    }

    // MARK: - Scenes

    /// Main window group — cross-platform, with macOS-only scene
    /// modifiers folded in via a single compile-time branch.
    private var mainWindow: some Scene {
        WindowGroup {
            rootContent
                .environment(AppSettings.shared)
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 400)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            HermesMacCommands()
        }
        #endif
    }

    // MARK: - Root content

    /// Resolves ``containerResult`` into either the real app UI or a
    /// recoverable error overlay. Declared as a computed property so
    /// the retry button can re-evaluate cleanly when `@State` changes.
    @ViewBuilder
    private var rootContent: some View {
        switch containerResult {
        case .success(let container):
            RootView()
                .modelContainer(container)
        case .failure(let error):
            LaunchView(error: error) {
                containerResult = ModelStack.rebuild()
            }
        }
    }

    #if os(macOS)
    /// Container used by the macOS Settings scene.
    ///
    /// Falls back to a fresh in-memory container if the on-disk build
    /// failed so the Settings scene itself still compiles and does not
    /// trip a SwiftData assertion — the user will see the LaunchView
    /// error overlay in the main window regardless.
    private var settingsContainer: ModelContainer {
        switch containerResult {
        case .success(let container):
            return container
        case .failure:
            // Best-effort empty container. `makeInMemoryContainer()`
            // only throws on a malformed schema, which is a
            // programmer error caught at test time; we still prefer
            // `preconditionFailure` over a force try because the stack
            // trace is useful if it ever does hit.
            if let fallback = try? ModelStack.makeInMemoryContainer() {
                return fallback
            }
            preconditionFailure(
                "Could not build any ModelContainer for Settings scene"
            )
        }
    }
    #endif
}
