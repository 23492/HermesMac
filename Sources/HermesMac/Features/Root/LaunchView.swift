import SwiftUI

/// Simple Hermes-branded launch screen.
///
/// Rendered as a full-bleed coloured background with a large white
/// "H" glyph. On iOS this is intended to be picked up as the SwiftUI
/// launch scene (via `UILaunchScreen` Info.plist keys once the app is
/// wrapped in an Xcode project). On macOS it can double as the splash
/// view shown while `RootView` is preparing its model container.
///
/// The brand colour is sourced from `AccentColor` in the asset catalog
/// so a redesign only has to touch one place.
public struct LaunchView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.accentColor
                .ignoresSafeArea()

            Text("H")
                .font(.system(size: 180, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    LaunchView()
}
