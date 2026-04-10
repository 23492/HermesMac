import MarkdownUI

// MARK: - HermesMac Markdown themes

public extension MarkdownUI.Theme {

    /// Markdown theme for assistant messages under the light color scheme.
    ///
    /// Built on top of `.gitHub`, which already provides bold headings,
    /// a monospaced font for code, and an inline-code background. A dedicated
    /// constant gives us one place to customise later (see task 11 for the
    /// Splash-based code block highlighter) without touching view code.
    ///
    /// Isolated to ``MainActor`` because ``MarkdownUI/Theme`` is not
    /// `Sendable` in 2.4.x and these values are only ever read from SwiftUI
    /// views, which are already main-actor bound.
    @MainActor
    static let hermesLight: MarkdownUI.Theme = .gitHub

    /// Markdown theme for assistant messages under the dark color scheme.
    ///
    /// Currently identical to ``hermesLight``. Split out so views can already
    /// pick the right theme based on the environment's color scheme; visual
    /// tuning will land in a follow-up task.
    @MainActor
    static let hermesDark: MarkdownUI.Theme = .gitHub
}
