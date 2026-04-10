import Foundation

#if os(iOS)
import UIKit
#endif

/// Cross-platform haptic feedback helpers.
///
/// On iOS these call into `UIImpactFeedbackGenerator` and
/// `UINotificationFeedbackGenerator`. On macOS every call is a no-op,
/// so calling sites stay platform-agnostic.
///
/// Main-actor isolated because UIKit feedback generators expect to be
/// touched from the main thread.
@MainActor
public enum HapticFeedback {

    /// Light impact — play when a user commits an action, e.g. sending
    /// a chat message.
    public static func impact() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// Success notification — play when a long-running action finishes
    /// successfully, e.g. when a streaming reply completes.
    public static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}
