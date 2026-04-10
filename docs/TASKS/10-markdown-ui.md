# Task 10: MarkdownUI integratie ✅ Done

**Status:** Done
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

- [x] MarkdownUI in Package.swift
- [x] Assistant messages renderen markdown correct
- [x] User messages blijven plain
- [x] Build en tests slagen
- [x] Commit: `feat(task10): integrate MarkdownUI for assistant messages`

## Completion notes

**Date:** 2026-04-10
**Commit:** zie git log (wordt ingevuld door commit)

Wat er is gebeurd:

- `Package.swift` kreeg `swift-markdown-ui` (resolved naar 2.4.1) als
  dependency en de `MarkdownUI` product als target dependency.
- Nieuwe file `Sources/HermesMac/DesignSystem/MarkdownTheme.swift` met
  `MarkdownUI.Theme.hermesLight` en `.hermesDark` — beide op dit moment
  gelijk aan `.gitHub`, maar als extension point opgezet zodat task 11 en
  volgende themaverfijningen geen view code hoeven te raken. De constants
  zijn `@MainActor`-geïsoleerd omdat `MarkdownUI.Theme` in 2.4.x niet
  `Sendable` is en deze waardes uitsluitend vanuit SwiftUI views (main
  actor) gelezen worden.
- `MessageBubbleView` splitst nu zijn content in een `@ViewBuilder`: user
  rollen krijgen een plain `Text`, assistant rollen een `Markdown(...)` met
  `@Environment(\.colorScheme)`-afhankelijke theme. Bubble styling
  (padding, achtergrond, corner radius) is ongewijzigd.

Afwijkingen van spec:

- Task spec suggereerde `extension MarkdownUI.Theme` zonder verdere
  opmerkingen. Onder Swift 6 strict concurrency eist de compiler expliciete
  isolatie voor static properties van niet-`Sendable` types; `@MainActor`
  was de juiste keuze.
- Het bubble "empty fallback" (spatie bij lege content) bestond al voor
  `Text`; ik hergebruik die voor `Markdown` via een `displayContent`
  helper zodat een streaming bubble niet collapse't naar zero height.

Verificatie:

- `swift build` — clean, geen warnings op de nieuwe code.
- `swift test` — 31/32 tests groen. De enige failure is pre-existing:
  `HermesClientTests.listModels maps 401 to httpStatus error`. Niet
  gerelateerd aan MarkdownUI; gelogd in `99-followups.md` #2.
- Tijdens verificatie ook een pre-existing compile-error weggewerkt:
  `ConversationRepositoryTests` miste `import Foundation` (aparte commit
  `fix(task07): ...` voor task 10).

Voor task 11: de `hermesLight/hermesDark` constants zijn het natuurlijke
aangrijpingspunt om een Splash-gebaseerde code block renderer in te hangen
via `.markdownBlockStyle(\.codeBlock)`. Bubble achtergrond (`systemGray6`)
kan conflicteren met `.gitHub`'s eigen code block achtergrond — dat is nu
visueel acceptabel maar een kandidaat voor tuning later.
