import SwiftUI

/// Root view for the HermesMac application.
public struct HermesMacApp: View {
    public init() {}

    public var body: some View {
        ContentView()
    }
}

/// Placeholder content view shown during scaffold phase.
public struct ContentView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("HermesMac")
                .font(.largeTitle.weight(.semibold))

            Text("Scaffolding in progress")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 300, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
