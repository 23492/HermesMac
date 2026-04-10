# Task 14: iOS NavigationStack shell + gestures

**Status:** Niet gestart
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

- [ ] iPhone landing toont conversation list
- [ ] Tap op conversation pusht naar chat
- [ ] Swipe back werkt
- [ ] Haptic feedback bij send
- [ ] Keyboard avoidance werkt
- [ ] Commit: `feat(task14): iOS shell with navigation stack and haptics`
