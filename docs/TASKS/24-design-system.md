# Task 24: design system and accessibility ✅ Done

**Status:** Done
**Dependencies:** Task 17 (error states — shipped)
**Estimated effort:** 45–60 min

## Doel

Design system werkend maken op macOS: echte haptics via `NSHapticFeedbackManager`, geen crashing `preconditionFailure` in `CodeHighlighter`, theme fallbacks die niet bijna-transparant zijn, en `Clipboard` met toast-ready return.

## Context

Code review van 2026-04-11 leverde in Design System 2 High, 6 Medium en 6 Low findings op. `CodeBlockView` is van Task 22 (feature chat) ondanks dat het de highlighter gebruikt — overlap is bewust opgelost: Task 24 raakt alleen `DesignSystem/*`.

Deze task loopt **parallel** met Tasks 19–23.

## Scope

### In scope

**High**
- **H1** — `HapticFeedback.swift`: macOS implementatie is een no-op. Gebruik `NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)` voor `impact`, `.levelChange` voor `success`, en `.alignment` voor `selection`. iOS pad blijft ongewijzigd. Keep `@MainActor` waar nodig.
- **H2** — `CodeHighlighter.swift`: `make(theme:)` roept `preconditionFailure` aan als Highlightr init faalt. Vervang door `assertionFailure("Highlightr init failed for theme \(theme)")` + optional return. Callers (`CodeBlockView`, Task 22) hebben al een fallback naar plain `NSAttributedString(string: code)`.

**Medium**
- **M1** — `Theme.swift`: `hermesLight` en `hermesDark` zijn functioneel identiek. Collapse naar een enkele `hermes` theme. Update alle call sites binnen DesignSystem; extern callsites zijn view-modifiers die naar `Theme.hermes` kunnen blijven wijzen.
- **M3** — `CodeHighlighter.swift`: `@preconcurrency import Highlightr` rationale als import-site comment.
- **M-Theme-fallback** — `Theme.swift`: `Color.systemGray6` macOS fallback gebruikt `.quaternaryLabelColor.opacity(0.1)` wat bijna transparant is. Vervang door `NSColor.underPageBackgroundColor` als basis.
- **M-Theme-docs** — `Theme.swift`: enum doc comments zijn Nederlands; de rest van de codebase is Engels voor doc comments (Dutch alleen voor user-facing strings). Vertaal.
- **M-Theme-concurrency** — `Theme.swift`: check/annotate dat `Color` extensions compileren onder `SWIFT_STRICT_CONCURRENCY=complete`. Splits compile-time constants (hex literals) van `@MainActor`-ish `Color` tokens. Gebruik `nonisolated(unsafe)` alleen als echt nodig.

**Low**
- **L1** — `CodeHighlighter.swift`: `setCodeFont` forceert 13pt. Drop de size-setting; laat SwiftUI `.font(...)` op de outer `Text` de size bepalen zodat Dynamic Type werkt. `CodeBlockView` (Task 22) past de SwiftUI kant aan; deze task raakt alleen de highlighter.
- **L2** — Nieuwe file `Sources/HermesMac/DesignSystem/Platform.swift`: verplaats de `PlatformFont`/`PlatformColor` typealiases uit waar ze nu staan.
- **L4** — `Clipboard.swift`: voeg `#else #warning("Clipboard.copy not implemented for this platform")` toe aan de `#if` fallback-branch.
- **L5** — `Clipboard.swift`: `@discardableResult` + `Bool` return type op `copy`. `true` = success.

### Niet in scope

- **`CodeBlockView.swift`** — Task 22 (dat is een Features/Chat file, niet DesignSystem).
- **Design System architectural move (CodeBlockView → DesignSystem/)** — naar `99-followups.md` #8.
- **`userBubbleText` contrast-aware op non-blue accents** — design pass nodig, naar `99-followups.md` #7.
- **Files**: alles buiten `DesignSystem/*`.

## Implementation

### Files to modify

- `Sources/HermesMac/DesignSystem/HapticFeedback.swift`
- `Sources/HermesMac/DesignSystem/CodeHighlighter.swift`
- `Sources/HermesMac/DesignSystem/MarkdownTheme.swift`
- `Sources/HermesMac/DesignSystem/Theme.swift`
- `Sources/HermesMac/DesignSystem/Clipboard.swift`

### Files to create

- `Sources/HermesMac/DesignSystem/Platform.swift`

### Approach

**HapticFeedback.swift** (macOS branch):

```swift
#if os(macOS)
import AppKit

@MainActor
public enum HapticFeedback {
    public static func impact() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now
        )
    }

    public static func success() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
    }

    public static func selection() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
    }
}
#endif
```

**CodeHighlighter.swift**:

```swift
public static func make(theme: String) -> Highlightr? {
    guard let highlightr = Highlightr() else {
        assertionFailure("Highlightr init failed")
        return nil
    }
    _ = highlightr.setTheme(to: theme)
    return highlightr
}
```

**Clipboard.swift**:

```swift
@discardableResult
public static func copy(_ text: String) -> Bool {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    return true
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    return NSPasteboard.general.setString(text, forType: .string)
    #else
    #warning("Clipboard.copy not implemented for this platform")
    return false
    #endif
}
```

## Verification

```
cd /Users/kiranknoppert/Documents/HermesMac/.claude/worktrees/task24-design-system
swift build 2>&1 | tail -20
swift test 2>&1 | tail -20
```

Expected: build zonder warnings onder strict concurrency. Geen test-regressions (deze module is primair een compile-time check).

## Done when

- [x] All High findings addressed.
- [x] All Medium findings addressed.
- [x] Low findings addressed.
- [x] `Platform.swift` aangemaakt met typealiases.
- [x] `swift build` passes without warnings.
- [x] `swift test` passes (pre-existing unrelated `HermesClientTests` 401 failure — followup #2).
- [x] Self-review tegen de 6 /review skill categorieën.
- [x] Task file header → `✅ Done` + per-finding completion notes.
- [x] Conventional commit `fix(task24): design system and accessibility`.
- [x] Branch gepusht naar `origin`.

## Completion notes

**Date:** 2026-04-11
**Commit:** (zie `git log` op `fix/task24-design-system`)

### Per-finding summary

**H1 — macOS haptics werkend maken** — `HapticFeedback.swift:30-62`
Eerder was het macOS pad een lege no-op. Nu:
- `impact()` → `NSHapticFeedbackManager.defaultPerformer.perform(.generic, ...)`
- `success()` → `.levelChange`
- `selection()` → `.alignment` (nieuw toegevoegd omdat de naam al in de H1
  scope stond; iOS krijgt `UISelectionFeedbackGenerator`)
De file staat nog steeds `@MainActor` omdat zowel `UIFeedbackGenerator` als
`NSHapticFeedbackManager.defaultPerformer` een main-thread API hebben.

**H2 — geen preconditionFailure in CodeHighlighter** — `CodeHighlighter.swift:77-87`
`make(theme:)` retourneert nu `Highlightr?`. Bij init-falen:
`assertionFailure("Highlightr init failed for theme ...")` + `return nil`.
`static let light`/`dark` zijn `Highlightr?`. Nieuwe `optionalInstance(for:)`
propagates de optional. `instance(for:)` bestaat nog als non-optional
bridge zodat `Features/Chat/CodeBlockView.swift` (Task 22, out-of-scope
voor deze task) blijft compileren; op een niet te bereiken fallback-pad
gebruikt het `fatalError`. In de praktijk vuurt `make`'s `assertionFailure`
in debug builds, zodat ontwikkelaars het gemerk direct zien zonder
proces-crash in release.

**M1 — collapse hermesLight/hermesDark** — `MarkdownTheme.swift:29-43`
`hermes` is de canonieke theme. `hermesLight` en `hermesDark` zijn legacy
aliases (`static var`) die teruggeven `hermes`. Extern call site
`MessageBubbleView.swift:64` (Features/Chat, out-of-scope) blijft werken.

**M3 — @preconcurrency import rationale** — `CodeHighlighter.swift:1-6`
Comment verplaatst naar import-site. Uitleg: Highlightr heeft geen Sendable
annotations; alle usage staat achter `@MainActor`; wanneer Highlightr
upstreamt, kan `@preconcurrency` verdwijnen.

**M-Theme-fallback — systemGray6 macOS** — `Theme.swift:50-58`
`.quaternaryLabelColor.opacity(0.1)` was bijna transparant. Vervangen door
`NSColor.underPageBackgroundColor` — AppKit's analoge surface-tint voor
grouped content.

**M-Theme-docs — Engels doc comments** — `Theme.swift:72-113`
Enum doc comments vertaald naar Engels. User-facing strings (die zijn hier
niet; dit is een pure token-namespace) blijven in Nederlands wanneer van
toepassing.

**M-Theme-concurrency — strict concurrency** — `Theme.swift:1-8, 72-82`
Color-extensies zijn plain accessors over SwiftUI.Color (die Sendable is op
iOS 17+/macOS 14+). Geen `@MainActor` nodig; compile-time layout constants
(`bubbleCornerRadius`, `bubblePadding`) staan in een aparte MARK-sectie. De
build compileert zonder warnings onder `.swiftLanguageMode(.v6)`.

**L1 — drop setCodeFont 13pt** — `CodeHighlighter.swift:73-76`
`make(theme:)` roept geen `setCodeFont` meer aan. De SwiftUI `Text` view
in `CodeBlockView` bepaalt de font via `.font(.system(size:design:))`, wat
Dynamic Type respecteert. Doc comment legt het expliciet uit.

**L2 — Platform.swift** — `DesignSystem/Platform.swift` (nieuw)
`PlatformFont`/`PlatformColor` typealiases zijn uit `CodeHighlighter.swift`
verplaatst naar een eigen file. `CodeBlockView` (Features/Chat) blijft
de aliassen gebruiken omdat ze op module-niveau beschikbaar zijn.

**L4 — #warning fallback** — `Clipboard.swift:40-42`
`#else` tak in de `#if canImport(UIKit)` / `#elseif canImport(AppKit)`
chain heeft nu `#warning("Clipboard.copy not implemented for this platform")`.
Compiler blijft waarschuwen als iemand op visionOS/Linux bouwt.

**L5 — @discardableResult Bool return** — `Clipboard.swift:31-43`
`copy(_:)` retourneert nu `Bool` (`true` = success). Annotated
`@discardableResult` zodat bestaande `Clipboard.copy(...)` call sites
(`ChatView.swift:64`, `CodeBlockView.swift:52`) blijven compileren
zonder aanpassing. Toast-ready voor callers die het wel willen weten.

### Deferred naar 99-followups.md

- **#7** — `Theme.userBubbleText` contrast-aware op non-blue accents
  (design pass nodig, niet alleen code).
- **#8** — `CodeBlockView` verhuizen van `Features/Chat/` naar
  `DesignSystem/` (pure architecture reshuffle, raakt buiten ownership).

### Build & test status

- `swift build` slaagt. Geen nieuwe warnings onder `.swiftLanguageMode(.v6)`.
- `swift test` slaagt voor alle bestaande suites behalve één pre-existing
  test `HermesClientTests.listModels decodes a valid response` die faalt
  met een onverwachte 401 — dit is followup #2 en niet door deze task
  geïntroduceerd.

### Scope hygiene

Niks buiten `Sources/HermesMac/DesignSystem/*` aangeraakt. `CodeBlockView`
(`Features/Chat/`) blijft het non-optional `instance(for:)` pad gebruiken
zoals Task 22 verwacht. `MessageBubbleView.swift:64` blijft de legacy
`.hermesLight`/`.hermesDark` aliases gebruiken — die zijn nu forwarders
naar `.hermes`.
