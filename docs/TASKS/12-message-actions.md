# Task 12: Message actions (copy, delete, regenerate)

**Status:** Niet gestart
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

- [ ] Long-press / right-click op een bubble toont menu
- [ ] Copy, Delete werken
- [ ] Regenerate werkt voor laatste assistant message
- [ ] Commit: `feat(task12): message context menu with copy delete regenerate`
