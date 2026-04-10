# Task 10: MarkdownUI integratie

**Status:** Niet gestart
**Dependencies:** Task 09
**Estimated effort:** 20 min

## Doel

Gebruik [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) om assistant messages als rich markdown te renderen. User messages blijven plain text (zijn toch gewoon wat de user typte).

## Waarom MarkdownUI

Open source, actief onderhouden, werkt op iOS 15+/macOS 12+, supports thema aanpassingen, handelt code blocks af met custom highlighters (zie task 11 voor Splash integratie). Geen Alamofire-achtige bloat.

Repo: https://github.com/gonzalezreal/swift-markdown-ui

## Scope

### In scope
- Voeg dependency toe aan `Package.swift`
- Vervang `Text(msg.content)` in assistant messages met `Markdown(msg.content)`
- Minimale thema aanpassing: monospaced code, bold headings, inline code met background

### Niet in scope
- Custom code block renderer met Splash (task 11)
- LaTeX / Mermaid / andere fancy renderers

## Implementation

Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
],
targets: [
    .target(
        name: "HermesMac",
        dependencies: [
            .product(name: "MarkdownUI", package: "swift-markdown-ui"),
        ],
        // ...
    )
]
```

Gebruik in `MessageBubbleView`:

```swift
import MarkdownUI

// In body, for assistant messages:
if message.role == "assistant" {
    Markdown(message.content)
        .markdownTheme(.hermesLight) // or .hermesDark based on colorScheme
        .textSelection(.enabled)
} else {
    Text(message.content)
        .textSelection(.enabled)
}
```

Theme config in een extension:

```swift
import MarkdownUI

extension MarkdownUI.Theme {
    static let hermesLight: MarkdownUI.Theme = .gitHub
    static let hermesDark: MarkdownUI.Theme = .gitHub  // start simple, customize later
}
```

## Done when

- [ ] MarkdownUI in Package.swift
- [ ] Assistant messages renderen markdown correct
- [ ] User messages blijven plain
- [ ] Build en tests slagen
- [ ] Commit: `feat(task10): integrate MarkdownUI for assistant messages`
