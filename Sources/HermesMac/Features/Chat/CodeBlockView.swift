// M4: `@preconcurrency` silences the strict-concurrency warnings that
// Highlightr would otherwise raise on `Highlightr` and `NSAttributedString`
// at each call site. Highlightr's public surface is not annotated
// `Sendable` yet; we isolate the shared instances on the main actor via
// ``CodeHighlighter`` so the warnings are safe to suppress at import time
// rather than plaster `nonisolated(unsafe)` across every call site.
@preconcurrency import Highlightr
import MarkdownUI
import SwiftUI

/// Custom code block view that replaces MarkdownUI's default code block
/// rendering inside the HermesMac markdown theme.
///
/// Layout:
/// - Header with the language label (uppercased) and a copy-to-clipboard button
/// - Horizontally scrollable body
/// - Code is syntax-highlighted via Highlightr (highlight.js through
///   JavaScriptCore), covering 190+ languages. If the language hint is
///   missing or unknown, Highlightr falls back to automatic language
///   detection; if that also fails, we render a plain `NSAttributedString`.
///
/// The theme tracks the surrounding SwiftUI `ColorScheme`: `github` in
/// light mode, `github-dark-dimmed` in dark mode. Background is read from
/// the Highlightr theme so the block stays visually coherent with its
/// highlight colors.
///
/// ### Performance
/// `Highlightr.highlight(_:as:)` is expensive — it bounces through a
/// JavaScriptCore context — and SwiftUI calls `body` more often than
/// you might expect. ``CodeBlockView`` defers to
/// ``HighlightedCodeBody``, an `Equatable` subview keyed by
/// `(code, language, colorScheme)`. When inputs don't change, SwiftUI
/// short-circuits the re-render via ``Equatable/==``, which is how we
/// keep streaming responses from re-highlighting every code block on
/// every chunk.
struct CodeBlockView: View {

    @Environment(\.colorScheme) private var colorScheme

    let configuration: CodeBlockConfiguration

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                HighlightedCodeBody(
                    code: trimmedContent,
                    language: configuration.language,
                    colorScheme: colorScheme
                )
                .equatable()
                .padding(CodeBlockStyle.bodyPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: CodeBlockStyle.cornerRadius))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(languageLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Clipboard.copy(trimmedContent)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy code")
        }
        .padding(.horizontal, CodeBlockStyle.headerHorizontalPadding)
        .padding(.vertical, CodeBlockStyle.headerVerticalPadding)
    }

    // MARK: - Helpers

    /// Background color from the active Highlightr theme. Highlightr emits
    /// the `.hljs` background as a plain property on `Theme`, not as an
    /// attribute on the produced `NSAttributedString`, so it has to be
    /// applied to the container separately.
    private var backgroundColor: Color {
        let highlighter = CodeHighlighter.instance(for: colorScheme)
        if let bg = highlighter.theme?.themeBackgroundColor {
            return Color(platformColor: bg)
        }
        return Color.black.opacity(0.1)
    }

    private var languageLabel: String {
        guard let language = configuration.language, !language.isEmpty else {
            return "CODE"
        }
        return language.uppercased()
    }

    /// MarkdownUI hands over the fenced code block's content with a trailing
    /// newline; stripping it avoids rendering a blank final line inside the
    /// code body.
    private var trimmedContent: String {
        var code = configuration.content
        while code.hasSuffix("\n") {
            code.removeLast()
        }
        return code
    }
}

// MARK: - Highlighted body

/// `Equatable` wrapper around the actual `Highlightr` call so SwiftUI
/// can skip re-running `highlight(_:as:)` when `body` re-evaluates with
/// the same inputs.
///
/// Equality is computed on the three inputs that determine the rendered
/// `NSAttributedString`: the code string, the language hint, and the
/// surrounding `ColorScheme`. If any of them change SwiftUI re-renders
/// and we pay the JavaScriptCore cost; otherwise it reuses the previous
/// output.
private struct HighlightedCodeBody: View, Equatable {
    let code: String
    let language: String?
    let colorScheme: ColorScheme

    var body: some View {
        let highlighter = CodeHighlighter.instance(for: colorScheme)
        let highlighted = highlighter.highlight(code, as: language)
            ?? NSAttributedString(string: code)
        Text(AttributedString(highlighted))
            .font(.system(size: CodeBlockStyle.fontSize, design: .monospaced))
            .textSelection(.enabled)
    }

    // `nonisolated` because `View` puts `body` on the main actor, which
    // in turn makes this whole struct main-actor-isolated. `Equatable`'s
    // `==` requirement is declared nonisolated, so without this
    // annotation Swift 6 strict concurrency rejects the conformance as
    // a potential data race.
    nonisolated static func == (lhs: HighlightedCodeBody, rhs: HighlightedCodeBody) -> Bool {
        lhs.code == rhs.code
            && lhs.language == rhs.language
            && lhs.colorScheme == rhs.colorScheme
    }
}

// MARK: - Visual constants

private enum CodeBlockStyle {
    static let fontSize: CGFloat = 13
    static let cornerRadius: CGFloat = 8
    static let bodyPadding: CGFloat = 12
    static let headerHorizontalPadding: CGFloat = 12
    static let headerVerticalPadding: CGFloat = 6
}

// MARK: - PlatformColor -> SwiftUI.Color bridge

private extension Color {

    /// Bridge a platform-native color (`UIColor` on iOS, `NSColor` on
    /// macOS) to a SwiftUI `Color` value. Used locally to convert
    /// Highlightr theme colors into SwiftUI land.
    init(platformColor: PlatformColor) {
        #if os(macOS)
        self.init(nsColor: platformColor)
        #else
        self.init(uiColor: platformColor)
        #endif
    }
}
