import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Cross-platform haptic feedback helpers.
///
/// On iOS these call into `UIImpactFeedbackGenerator` and
/// `UINotificationFeedbackGenerator`. On macOS they call into
/// `NSHapticFeedbackManager.defaultPerformer`, which drives the Force
/// Touch trackpad and the Magic Trackpad 2+ on supported hardware.
/// Call sites stay platform-agnostic: every method is a safe no-op on
/// unsupported platforms.
///
/// Main-actor isolated because both AppKit and UIKit feedback generators
/// expect to be touched from the main thread.
@MainActor
public enum HapticFeedback {

    /// Light impact — play when a user commits an action, e.g. sending
    /// a chat message.
    public static func impact() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now
        )
        #endif
    }

    /// Success notification — play when a long-running action finishes
    /// successfully, e.g. when a streaming reply completes.
    public static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
        #endif
    }

    /// Selection tick — play for discrete UI selection changes, e.g.
    /// picking a new conversation in the sidebar.
    public static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        #endif
    }
}
