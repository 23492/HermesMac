# Task 12: Message actions (copy, delete, regenerate) ✅ Done

**Status:** ✅ Done
**Dependencies:** Task 09
**Estimated effort:** 25 min

## Doel

Per-bericht context menu met acties:
- **Copy** (alle messages)
- **Delete** (alle messages)
- **Regenerate** (alleen assistant)
- **Edit** (alleen user, latere followup — voor v1 mag dit een stub zijn)

## Scope

### In scope
- Context menu via `.contextMenu { }` modifier op `MessageBubbleView`
- Copy action via cross-platform pasteboard helper
- Delete via `ConversationRepository`
- Regenerate: delete laatste assistant bericht, resend laatste user bericht via `ChatModel`

### Niet in scope
- Full edit UI voor user messages
- Swipe actions (iOS)
- Bulk select en delete

## Implementation notes

Regenerate flow in `ChatModel`:

```swift
public func regenerate() async {
    guard let lastAssistant = messages.last, lastAssistant.role == "assistant" else { return }
    guard messages.count >= 2 else { return }
    let lastUser = messages[messages.count - 2]
    guard lastUser.role == "user" else { return }

    // Remove assistant placeholder
    try? repository.deleteMessage(lastAssistant)
    messages.removeAll { $0.id == lastAssistant.id }

    // Re-run the send with the existing user message (don't duplicate)
    // Shortcut: build history without the deleted assistant and call the same streaming logic
    // as send() but skip the user message insertion.
}
```

Dit vereist een kleine refactor van `send()` in task 08. Factor de "start streaming with current history" uit in een private helper `startStreaming()` die zowel `send()` als `regenerate()` aanroepen.

## Cross-platform clipboard helper

```swift
// DesignSystem/Clipboard.swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum Clipboard {
    public static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
```

## Done when

- [x] Long-press / right-click op een bubble toont menu
- [x] Copy, Delete werken
- [x] Regenerate werkt voor laatste assistant message
- [x] Commit: `feat(task12): message context menu with copy delete regenerate`

## Completion notes

**Date:** 2026-04-10
**Commit:** 27415eb

`MessageBubbleView` krijgt nu drie closure parameters (`onCopy`, `onDelete`,
`onRegenerate`) en zet een `.contextMenu { ... }` op de bubble. Regenerate
wordt alleen in het menu getoond als de caller een closure meegeeft én het
geen user message is; `ChatView` geeft alleen een closure door voor het
allerlaatste assistant bericht, omdat `ChatModel.regenerate()` altijd de
staart van de conversatie vervangt.

`ChatModel.send()` is gerefactored: de "maak placeholder + snapshot
history + start stream" flow is uitgelicht als private `startStreaming()`
zodat zowel `send()` als de nieuwe `regenerate()` hem kunnen aanroepen.
`regenerate()` verwijdert eerst het laatste assistant bericht (repository
+ in-memory) en roept dan `startStreaming()`. Guards voor "niet streamen",
"laatste message is assistant" en "daarvoor staat een user message".

`Clipboard.copy(_:)` was al gebouwd in task 11 voor de code block copy
button, dus kon direct worden hergebruikt — geen nieuwe helper nodig.

`ChatModelTests` breidde uit met drie regenerate-tests (geen assistant
→ no-op, happy path vervangt tail en start streaming, streaming in gang
→ genegeerd). Alle 34 tests slagen; de enige failure is nog steeds de
pre-existing `HermesClientTests.listModels maps 401` uit
`99-followups.md` #2 — geen regressie van deze task.

Build niet geverifieerd onder Xcode/simulator maar wel onder `swift build`
en `swift test` op macOS (Swift 6.3, strict concurrency).
