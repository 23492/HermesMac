import Foundation
import SwiftUI

/// Simple Hermes-branded launch screen.
///
/// Rendered as a full-bleed coloured background with a large white
/// "H" glyph. On iOS this is intended to be picked up as the SwiftUI
/// launch scene (via `UILaunchScreen` Info.plist keys once the app is
/// wrapped in an Xcode project). On macOS it can double as the splash
/// view shown while `RootView` is preparing its model container.
///
/// When the optional ``error`` parameter is non-nil, an inline error
/// overlay is rendered on top of the brand panel. This is used by the
/// app shell as a recoverable crash screen when ``ModelStack/shared``
/// fails to build: the user sees the failure, a "Probeer opnieuw"
/// button that retries the container build, and a link to file a bug.
///
/// The brand colour is sourced from `AccentColor` in the asset catalog
/// so a redesign only has to touch one place.
public struct LaunchView: View {

    /// Destination for the "Verzend logs" link in the error overlay.
    /// Compile-time constant — same force-unwrap pattern as
    /// ``BackendConfig/baseURL``.
    private static let issueTrackerURL = URL(
        string: "https://github.com/kiran/HermesMac/issues/new"
    )!

    /// Optional error to surface in an overlay. `nil` renders a plain
    /// brand splash.
    private let error: Error?

    /// Invoked when the user taps "Probeer opnieuw" in the error
    /// overlay. Expected to retry whatever failed (for the app shell:
    /// `ModelStack.rebuild()`). `nil` hides the retry button.
    private let retry: (@MainActor () -> Void)?

    /// Creates a plain brand splash (no error overlay).
    public init() {
        self.error = nil
        self.retry = nil
    }

    /// Creates a splash with an error overlay.
    /// - Parameters:
    ///   - error: The underlying error to display to the user.
    ///   - retry: Action invoked when the user presses "Probeer
    ///     opnieuw". Typically re-runs the failed operation.
    public init(error: Error, retry: @escaping @MainActor () -> Void) {
        self.error = error
        self.retry = retry
    }

    public var body: some View {
        ZStack {
            Color.accentColor
                .ignoresSafeArea()

            Text("H")
                .font(.system(size: 180, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .accessibilityHidden(true)

            if let error {
                errorOverlay(for: error)
            }
        }
    }

    // MARK: - Error overlay

    @ViewBuilder
    private func errorOverlay(for error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(String(localized: "launch.error.title", defaultValue: "Kon opslag niet openen"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text(error.localizedDescription)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let retry {
                Button {
                    retry()
                } label: {
                    Label(String(localized: "launch.error.retry", defaultValue: "Probeer opnieuw"), systemImage: "arrow.clockwise")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }

            Link(destination: Self.issueTrackerURL) {
                Label(String(localized: "launch.error.sendLogs", defaultValue: "Verzend logs"), systemImage: "paperplane")
                    .font(.footnote)
            }
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .padding(32)
    }
}

#Preview("Splash") {
    LaunchView()
}

/// Demo error used only by the preview below.
private struct PreviewError: LocalizedError {
    let errorDescription: String?
}

#Preview("Error") {
    LaunchView(
        error: PreviewError(errorDescription: "SwiftData schema corrupt."),
        retry: {}
    )
}
