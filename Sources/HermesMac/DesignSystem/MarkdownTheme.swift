import MarkdownUI

// MARK: - HermesMac Markdown themes

public extension MarkdownUI.Theme {

    /// Markdown theme for HermesMac assistant messages.
    ///
    /// Built on top of `.gitHub`, which already provides bold headings,
    /// a monospaced font for code, and an inline-code background.
    /// Fenced code blocks are replaced with ``CodeBlockView`` so code is
    /// syntax highlighted via Highlightr (highlight.js through
    /// JavaScriptCore, covering 190+ languages) and every block gets a
    /// language label and a copy button.
    ///
    /// Light and dark variants were previously split into two constants
    /// (`hermesLight` / `hermesDark`) but were functionally identical:
    /// ``CodeBlockView`` already branches on the surrounding SwiftUI
    /// `ColorScheme` to pick the right Highlightr theme, and the
    /// surrounding message bubble controls body text color. A single
    /// `hermes` theme is the source of truth; the legacy aliases below
    /// forward to it for backwards compatibility with existing call
    /// sites (e.g. view modifiers that pass `colorScheme == .dark ?
    /// .hermesDark : .hermesLight`).
    ///
    /// Isolated to ``MainActor`` because ``MarkdownUI/Theme`` is not
    /// `Sendable` in 2.4.x and these values are only ever read from
    /// SwiftUI views, which are already main-actor bound.
    @MainActor
    static let hermes: MarkdownUI.Theme = MarkdownUI.Theme.gitHub
        .codeBlock { configuration in
            CodeBlockView(configuration: configuration)
        }

    /// Legacy alias for ``hermes``. Kept so existing light-mode call
    /// sites continue to compile; prefer ``hermes`` in new code.
    @MainActor
    static var hermesLight: MarkdownUI.Theme { hermes }

    /// Legacy alias for ``hermes``. Kept so existing dark-mode call
    /// sites continue to compile; prefer ``hermes`` in new code.
    @MainActor
    static var hermesDark: MarkdownUI.Theme { hermes }
}
