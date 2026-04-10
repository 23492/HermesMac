# Task 11: Syntax highlighting via Splash

**Status:** Niet gestart
**Dependencies:** Task 10
**Estimated effort:** 30 min

## Doel

Custom code block renderer in MarkdownUI die [Splash](https://github.com/JohnSundell/Splash) gebruikt voor Swift syntax highlighting, en voor andere talen een simpele monospaced fallback.

## Waarom Splash

- Native Swift, geen dependencies
- Bekend en goed onderhouden (John Sundell)
- Ondersteunt eigen themes
- Perfect voor Swift, minder voor andere talen — daarom fallback naar monospaced

Voor andere talen zou je Prism of Highlight.js via WKWebView kunnen embedden maar dat is overkill. Plain monospaced is al beter dan niks.

Repo: https://github.com/JohnSundell/Splash

## Scope

### In scope
- Dependency toevoegen
- `CodeBlockRenderer` struct die een `CodeBlockConfiguration` naar een styled view mapt
- Swift code → Splash highlighter
- Andere talen → monospaced Text met background
- Copy knop in de rechter bovenhoek van elk code block

### Niet in scope
- Meertalige highlighting (Swift only + plain)
- Line numbers
- Code folding

## Implementation

Package.swift dependency:
```swift
.package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),
```

Code block renderer skelet:

```swift
import SwiftUI
import MarkdownUI
import Splash

struct HermesCodeBlockRenderer: CodeBlockRenderer {
    let fontSize: CGFloat = 13

    func makeBody(configuration: CodeBlockConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(language: configuration.language)
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                highlightedText(configuration.content, language: configuration.language)
                    .font(.system(size: fontSize, design: .monospaced))
                    .padding(12)
            }
        }
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func highlightedText(_ code: String, language: String?) -> some View {
        if language?.lowercased() == "swift" {
            let theme = Splash.Theme.sundellsColors(withFont: .init(size: fontSize))
            let highlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: theme))
            let attributed = highlighter.highlight(code)
            Text(AttributedString(attributed))
                .textSelection(.enabled)
        } else {
            Text(code)
                .textSelection(.enabled)
        }
    }

    private func header(language: String?) -> some View {
        HStack {
            Text(language?.uppercased() ?? "CODE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { /* copy action */ }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
```

Toepassen in theme:
```swift
extension MarkdownUI.Theme {
    static var hermes: MarkdownUI.Theme {
        .gitHub
            .codeBlock { configuration in
                HermesCodeBlockRenderer().makeBody(configuration: configuration)
            }
    }
}
```

## Done when

- [ ] Splash in Package.swift
- [ ] Swift code blocks zijn gehighlighted
- [ ] Andere talen zijn monospaced met background
- [ ] Copy knop werkt
- [ ] Commit: `feat(task11): Swift syntax highlighting in code blocks`

## Open punten

- Copy knop implementatie is platform-specifiek (UIPasteboard vs NSPasteboard). Maak een kleine cross-platform helper in `DesignSystem/Clipboard.swift`.
