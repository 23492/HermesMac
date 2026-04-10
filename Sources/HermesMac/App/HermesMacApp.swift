import SwiftUI
import SwiftData

/// Root view for the HermesMac application.
///
/// Sets up the SwiftData model container and injects `AppSettings`
/// into the environment so all child views can access them.
public struct HermesMacApp: View {
    public init() {}

    public var body: some View {
        RootView()
            .modelContainer(ModelStack.shared)
            .environment(AppSettings.shared)
    }
}

#Preview {
    HermesMacApp()
}
