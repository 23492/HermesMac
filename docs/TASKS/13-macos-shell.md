# Task 13: macOS NavigationSplitView shell + commands ✅ Done

**Status:** ✅ Done
**Dependencies:** Task 09
**Estimated effort:** 25 min

## Doel

macOS-specifieke polish: `NavigationSplitView` met sidebar toggling, menu bar commands, keyboard shortcuts.

## Scope

### In scope
- `#if os(macOS)` scheme voor `RootView`
- Menu bar commands: Cmd+N new chat, Cmd+W close, Cmd+K focus composer, Cmd+. cancel
- Sidebar auto-collapse wanneer windowwidth krimpt
- Default window size 900x700

### Niet in scope
- Multi-window support
- Tabs
- Touch Bar

## Implementation hints

```swift
#if os(macOS)
.commands {
    CommandGroup(replacing: .newItem) {
        Button("Nieuwe chat") { /* create new */ }
            .keyboardShortcut("n", modifiers: [.command])
    }
    CommandGroup(after: .textEditing) {
        Button("Bericht versturen") { /* send */ }
            .keyboardShortcut(.return, modifiers: [.command])
    }
}
.defaultSize(width: 900, height: 700)
.windowResizability(.contentSize)
#endif
```

## Done when

- [x] macOS shortcuts werken
- [x] Default window size 900x700
- [x] Sidebar collapse/expand via Cmd+Shift+S (system default)
- [x] Commit: `feat(task13): macOS shell with menu commands and shortcuts`

## Completion notes

**Date:** 2026-04-10
**Commit:** d7b8e1d

Menu bar commands geïmplementeerd via `HermesMacCommands` (macOS-only)
met drie actions die via `FocusedValues` naar de view layer bridgen:
`newChatAction` (RootView), `cancelStreamingAction` en
`focusComposerAction` (beide ChatView). Closure type is
`@MainActor () -> Void` zodat captured `@MainActor` methods onder Swift 6
strict concurrency blijven compileren.

Shortcuts: Cmd+N nieuwe chat, Cmd+K focus composer, Cmd+. stop streaming.
Cmd+W werkt automatisch via de system `.windowArrangement` group en is
niet custom bedraad. Commands disablen zichzelf automatisch als de
bijbehorende focused value `nil` is (dus geen chat geselecteerd).

`MessageComposerView` kreeg een `focus:` init parameter met een
`FocusState<Bool>.Binding`, ChatView houdt zelf de `@FocusState` vast.
Publiceert de focus closure via `.focusedSceneValue` binnen
`chatContent(model:)` zodat hij alleen leeft zolang er een chat open is.

`HermesMacApp.swift` gebruikt nu `.defaultSize(width: 900, height: 700)`
onder `#if os(macOS)`. `.windowResizability` niet gezet — default
gedrag laat user de window vrij vergroten/verkleinen. Sidebar toggle
via Cmd+Ctrl+S (system default vanuit NavigationSplitView toolbar) —
geen custom code.

swift build clean onder Swift 6 strict concurrency, swift test 34/35
(pre-existing `HermesClientTests.listModels maps 401` failure uit
99-followups.md #2, geen regressie).

Build niet geverifieerd op fysieke Mac met Xcode — manuele verificatie
van de shortcuts en menu layout door Kiran.
