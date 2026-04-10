# Task 14: iOS NavigationStack shell + gestures ✅ Done

**Status:** ✅ Done
**Dependencies:** Task 09
**Estimated effort:** 25 min

## Doel

iOS-specifieke polish: `NavigationStack` op de landing (conversation list), push naar chat, swipe-back gesture, haptic feedback bij send.

## Scope

### In scope
- `#if os(iOS)` branch in `RootView`
- Conversation list als landing, tap om naar chat te navigeren
- Settings sheet accessible via toolbar
- Haptic feedback: light impact op send, success feedback op reply complete
- Keyboard handling: composer rises met keyboard, scroll view krimpt correct

### Niet in scope
- iPad-optimized split layout (kan later)
- Share sheet
- Drag and drop

## Implementation hints

- Gebruik `UINotificationFeedbackGenerator` en `UIImpactFeedbackGenerator` voor haptics
- `.safeAreaInset(edge: .bottom)` voor de composer
- `.toolbar { ToolbarItem(placement: .topBarTrailing) { ... } }` voor settings gear

## Done when

- [x] iPhone landing toont conversation list
- [x] Tap op conversation pusht naar chat
- [x] Swipe back werkt
- [x] Haptic feedback bij send
- [x] Keyboard avoidance werkt
- [x] Commit: `feat(task14): iOS shell with navigation stack and haptics`

## Completion notes

**Date:** 2026-04-10
**Commit:** 1a282a4

`RootView` gesplitst in `iosBody` (NavigationStack met `[UUID]` path)
en `macOSBody` (bestaande NavigationSplitView). `createNewChat()` zet
op iOS `navigationPath = [conversation.id]` zodat een nieuwe chat
meteen gepusht wordt; op macOS blijft het de `selectedConversationID`
binding. De shared `@Query`, selection state en delete-actions leven
in de parent zodat beide branches dezelfde bron van waarheid delen.

`ConversationListView` kreeg een iOS-tak die `NavigationLink(value:)`
rijen gebruikt (zodat `navigationDestination(for: UUID.self)` in
RootView de juiste ChatView opbouwt) en een macOS-tak die de
bestaande `List(selection:)` versie houdt. Toolbar placement is
`.topBarTrailing` op iOS, `.automatic` op macOS.

Nieuwe `HapticFeedback` helper is main-actor gated, wrapt
`UIImpactFeedbackGenerator(.light)` en `UINotificationFeedbackGenerator`
achter `#if os(iOS)` zodat de call sites in `ChatView` cross-platform
blijven — op macOS zijn alle entry points no-ops. `ChatView` fires
`impact()` in de composer `onSend` closure en `success()` via een
`onChange(of: model.isStreaming)` observer, maar alleen wanneer de
reply daadwerkelijk content landde (voorkomt een buzz bij cancel).

Composer keyboard handling via `.safeAreaInset(edge: .bottom)` rond
de error banner + `MessageComposerView` stack, `.background(.bar)`
voor de materiaal-achtergrond op beide platforms. SwiftUI lift het
inset automatisch boven het keyboard op iOS.

Settings-sheet toolbar entry uit de scope is **niet** bedraad in
deze taak: de Settings view zelf komt pas in task 15. Zodra die
bestaat wordt de gear button in `ConversationListView.iosList`'s
toolbar toegevoegd. Kiran akkoord met dit als kleine uitzondering
op de strikt volgordelijke afwerking.

swift build clean onder Swift 6 strict concurrency, swift test 34/35
(pre-existing `HermesClientTests.listModels decodes a valid response`
failure uit 99-followups.md #2, geen regressie).

Build niet geverifieerd op een fysieke iPhone met Xcode — manuele
verificatie van de navigation push, swipe back gesture, haptic
timing en keyboard avoidance door Kiran.
