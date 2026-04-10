import MarkdownUI

// MARK: - HermesMac Markdown themes

public extension MarkdownUI.Theme {

    /// Markdown theme for assistant messages under the light color scheme.
    ///
    /// Built on top of `.gitHub`, which already provides bold headings, a
    /// monospaced font for code, and an inline-code background. Fenced code
    /// blocks are replaced with ``CodeBlockView`` so code is syntax
    /// highlighted via Highlightr (highlight.js through JavaScriptCore,
    /// covering 190+ languages) and every block gets a language label and
    /// a copy button.
    ///
    /// Isolated to ``MainActor`` because ``MarkdownUI/Theme`` is not
    /// `Sendable` in 2.4.x and these values are only ever read from SwiftUI
    /// views, which are already main-actor bound.
    @MainActor
    static let hermesLight: MarkdownUI.Theme = MarkdownUI.Theme.gitHub
        .codeBlock { configuration in
            CodeBlockView(configuration: configuration)
        }

    /// Markdown theme for assistant messages under the dark color scheme.
    ///
    /// Currently identical to ``hermesLight``: ``CodeBlockView`` picks the
    /// correct Highlightr theme from the surrounding SwiftUI `ColorScheme`,
    /// and the rest of the body text inherits color from the bubble. Split
    /// into two constants so views can already branch on color scheme;
    /// visual tuning of non-code elements can land here later.
    @MainActor
    static let hermesDark: MarkdownUI.Theme = MarkdownUI.Theme.gitHub
        .codeBlock { configuration in
            CodeBlockView(configuration: configuration)
        }
}
