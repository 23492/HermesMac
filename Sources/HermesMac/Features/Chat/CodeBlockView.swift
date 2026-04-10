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
struct CodeBlockView: View {

    @Environment(\.colorScheme) private var colorScheme

    let configuration: CodeBlockConfiguration

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                codeBody
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

    // MARK: - Code body

    @ViewBuilder
    private var codeBody: some View {
        let highlighted = highlighter.highlight(trimmedContent, as: configuration.language)
            ?? NSAttributedString(string: trimmedContent)
        Text(AttributedString(highlighted))
            .font(.system(size: CodeBlockStyle.fontSize, design: .monospaced))
            .textSelection(.enabled)
    }

    // MARK: - Helpers

    private var highlighter: Highlightr {
        CodeHighlighter.instance(for: colorScheme)
    }

    /// Background color from the active Highlightr theme. Highlightr emits
    /// the `.hljs` background as a plain property on `Theme`, not as an
    /// attribute on the produced `NSAttributedString`, so it has to be
    /// applied to the container separately.
    private var backgroundColor: Color {
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
