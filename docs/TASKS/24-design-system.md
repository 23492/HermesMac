# Task 24: design system and accessibility

**Status:** Niet gestart
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

- [ ] All High findings addressed.
- [ ] All Medium findings addressed.
- [ ] Low findings addressed.
- [ ] `Platform.swift` aangemaakt met typealiases.
- [ ] `swift build` passes without warnings.
- [ ] `swift test` passes (module heeft weinig tests maar mag niet regresseren).
- [ ] Self-review tegen de 6 /review skill categorieën — met bijzondere aandacht voor Architecture (module boundaries) en Performance (highlightr geen font-forcing).
- [ ] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [ ] Conventional commit `fix(task24): design system and accessibility` op branch `fix/task24-design-system`, met `file:line` referenties in body.
- [ ] Branch gepusht naar `origin`.
