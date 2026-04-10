@preconcurrency import Highlightr
import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#endif

/// Shared ``Highlightr`` instances for HermesMac code blocks.
///
/// Highlightr has no `Sendable` annotations; `@MainActor` isolation keeps
/// instances on a single actor which is also where SwiftUI view bodies run.
/// One instance per color scheme is reused across every code block in the
/// entire app — each `Highlightr` carries a `JSContext` that is roughly
/// 5 MB of resident memory, so building a new one per view is wasteful.
@MainActor
enum CodeHighlighter {

    /// Highlighter configured with a light theme (`github`).
    static let light: Highlightr = make(theme: "github")

    /// Highlighter configured with a dark theme (`github-dark-dimmed`).
    static let dark: Highlightr = make(theme: "github-dark-dimmed")

    /// Pick the correct singleton for a SwiftUI ``ColorScheme``.
    static func instance(for colorScheme: ColorScheme) -> Highlightr {
        colorScheme == .dark ? dark : light
    }

    private static func make(theme name: String) -> Highlightr {
        guard let highlightr = Highlightr() else {
            preconditionFailure(
                "Highlightr could not initialise — bundled highlight.min.js missing?"
            )
        }
        _ = highlightr.setTheme(to: name)
        if let theme = highlightr.theme {
            theme.setCodeFont(
                PlatformFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            )
        }
        return highlightr
    }
}
