import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Cross-platform helpers for writing to the system pasteboard.
///
/// Abstracts `UIPasteboard` on iOS and `NSPasteboard` on macOS behind a
/// single main-actor API so views and view models can copy text without
/// scattering `#if os(...)` blocks across the codebase.
public enum Clipboard {

    /// Write a plain-text string to the system pasteboard, replacing any
    /// previous contents.
    ///
    /// Main-actor isolated because both `UIPasteboard` and `NSPasteboard`
    /// are expected to be touched from the main thread in UI contexts.
    @MainActor
    public static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #endif
    }
}
