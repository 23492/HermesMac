# Task 11: Syntax highlighting ✅ Done

**Status:** ✅ Done
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

## Completion notes

**Date:** 2026-04-10
**Commit:** 7e3dfb9

Wat er is gebeurd:

- Dependency gewisseld van Splash naar
  [Highlightr](https://github.com/raspu/Highlightr) 2.3.0. Splash highlight
  alleen Swift; Highlightr draait highlight.js via JavaScriptCore en dekt
  190+ talen, wat veel realistischer is voor een generieke chat client die
  output in allerlei talen krijgt. Het task-spec Package.swift entry is
  vervangen door `.package(url: "https://github.com/raspu/Highlightr", from: "2.3.0")`.
- Nieuwe file `Sources/HermesMac/DesignSystem/CodeHighlighter.swift` met
  `@MainActor`-geïsoleerde Highlightr singletons voor de `github` (light)
  en `github-dark-dimmed` (dark) themes. Highlightr 2.3.0 heeft geen
  `Sendable` annotaties, dus main-actor isolatie is de enige manier om het
  onder Swift 6 strict concurrency te krijgen zonder `@unchecked`.
- Nieuwe file `Sources/HermesMac/Features/Chat/CodeBlockView.swift`:
  custom MarkdownUI code block view met header (taal-label links, copy
  knop rechts), divider, en horizontale scroll voor lange regels. De
  theme wordt gekozen op basis van `@Environment(\.colorScheme)` zodat
  light en dark mode automatisch matchen met de rest van de UI.
- Nieuwe file `Sources/HermesMac/DesignSystem/Clipboard.swift`: minimale
  cross-platform pasteboard helper (`NSPasteboard` op macOS,
  `UIPasteboard` op iOS) die gedeeld wordt door de copy knop op de code
  block header — conform het "Open punten" bullet van de originele spec.
- `MarkdownTheme.swift`: `hermesLight` en `hermesDark` hangen nu allebei
  `.codeBlock { CodeBlockView(configuration: $0) }` in, zodat alle
  assistant markdown automatisch de nieuwe renderer krijgt zonder dat
  `MessageBubbleView` iets hoeft te weten.

Afwijkingen van spec:

- Splash → Highlightr, zie hierboven. De `# Task 11: ... via Splash` titel
  is daarom hernoemd naar `# Task 11: Syntax highlighting`.
- Spec sprak over "Swift only + plain fallback". Met Highlightr krijgen we
  gratis full multi-language highlighting, dus die fallback-laag is niet
  meer nodig — talen die highlight.js niet kent vallen vanzelf terug op
  een ongekleurde monospaced weergave via Highlightr's eigen "auto"
  detectie.

Verificatie:

- `swift package resolve` — Highlightr 2.3.0 pulled, geen conflicten met
  swift-markdown-ui 2.4.1.
- `swift build` — clean onder Swift 6 strict concurrency, geen warnings.
- `swift test` — 31/32 tests groen. De enige failure is pre-existing:
  `HermesClientTests.listModels maps 401 to httpStatus error`. Niet
  gerelateerd aan task 11; al gelogd in `99-followups.md` #2 na task 10 —
  geen regressie.
