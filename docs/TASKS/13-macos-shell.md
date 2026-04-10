# Task 13: macOS NavigationSplitView shell + commands

**Status:** Niet gestart
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

- [ ] macOS shortcuts werken
- [ ] Default window size 900x700
- [ ] Sidebar collapse/expand via Cmd+Shift+S (system default)
- [ ] Commit: `feat(task13): macOS shell with menu commands and shortcuts`
