import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Cross-platform helpers for writing to the system pasteboard.
///
/// Abstracts `UIPasteboard` on iOS and `NSPasteboard` on macOS behind a
/// single main-actor API so views and view models can copy text without
/// scattering `#if canImport(...)` blocks across the codebase.
public enum Clipboard {

    /// Write a plain-text string to the system pasteboard, replacing any
    /// previous contents.
    ///
    /// Main-actor isolated because both `UIPasteboard` and `NSPasteboard`
    /// are expected to be touched from the main thread in UI contexts.
    ///
    /// - Parameter text: The string to place on the pasteboard.
    /// - Returns: `true` when the copy was handed off to the platform
    ///   pasteboard successfully, `false` otherwise (e.g. the macOS
    ///   pasteboard rejected the write, or the current platform has no
    ///   supported pasteboard backend). The return value is annotated
    ///   `@discardableResult` so call sites that don't care about
    ///   toast-style feedback can keep calling `Clipboard.copy(...)`
    ///   without ceremony.
    @MainActor
    @discardableResult
    public static func copy(_ text: String) -> Bool {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        return true
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
        #else
        #warning("Clipboard.copy not implemented for this platform")
        return false
        #endif
    }
}
