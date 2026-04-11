# Task 22: chat feature hardening

**Status:** Niet gestart
**Dependencies:** Task 17 (error states — shipped)
**Estimated effort:** 60–90 min

## Doel

Streaming updates daadwerkelijk door `@Observable` laten vloeien, memory leaks in long-lived Tasks fixen, state-binding richting view strakker trekken, en Highlightr overhead temmen.

## Context

Code review van 2026-04-11 leverde in Chat 3 High, 6 Medium en 5 Low findings op. H4 (per-call `HermesEndpoint`) zit in Task 22's ownership set van files maar raakt de API van `HermesClient` (Task 19). Die fix gaat naar `99-followups.md` zodat hij als aparte pure refactor gedaan kan worden als de networking API stabiel is.

Deze task loopt **parallel** met Tasks 19–21, 23–24. Files in `Features/Chat/*` en `Tests/HermesMacTests/ChatModelTests.swift` zijn van deze agent.

## Scope

### In scope

**High**
- **H1** — `ChatModel.swift`: streaming loop doet `assistantMessage.content += chunk`. `assistantMessage` is een SwiftData entity referentie; het is niet gegarandeerd dat `@Observable` (of SwiftUI's observation van de array) dit ziet. Fix door na elke chunk append de message terug te schrijven in `messages` (`if let idx = messages.firstIndex(where: { $0.id == assistantMessage.id }) { messages[idx] = assistantMessage }`) OF door `messages` om te bouwen naar een computed property over `conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })`. Kies wat het cleanste compileert; computed is voorkeur. Gerelateerde M1 gaat mee.
- **H2** — `ChatModel.swift`: `slowReplyTask = Task { ... }` en `streamingTask = Task { ... }` capturen `self` strong. Gebruik `Task { [weak self] in guard let self else { return }; ... }`. Geldt voor beide.
- **H3** — `ChatModel.swift`: `chatError` is `internal(set)` en wordt vanuit de view direct geschreven (zoek callers). Zet het naar `private(set)` en voeg `public func dismissError()` toe. Update ChatView callers.

**Medium**
- **M1** — Zie H1: routing alle mutaties via `syncMessages()` helper als computed property te bewerkelijk is.
- **M2** — `ChatView.swift`: `.onChange(of: last?.content)` triggert animations mid-stream. Verwijder de animation daar en animate alleen op `isStreaming` transitions, of gebruik `withAnimation(nil)` voor mid-stream updates.
- **M3** — `ChatView.swift`: `ForEach(messages) { msg in ... .id(msg.id) }` — de `.id(msg.id)` op row-niveau is dubbel want `ForEach` gebruikt al `id`. Weghalen.
- **M4** — `CodeBlockView.swift`: `@preconcurrency import Highlightr` heeft een comment op class-level. Verplaats naar import-site zodat rationale meteen zichtbaar is.
- **M5** — `CodeBlockView.swift`: cache `Highlightr.highlight(...)` resultaat per `(trimmedContent, language)` key. Gebruik een `@State` dict of een lazy var. Alternatief: wrap de body in een `Equatable` subview zodat SwiftUI niet opnieuw highlightet bij identieke input.
- **M6** — `MessageComposerView.swift` (en de caller): de `Binding(get:set:)` trampoline voor `inputText` vervangen door `@Bindable var model = model` en `$model.inputText`.

**Low**
- **L1** — `MessageBubbleView.swift`: `onRegenerate: (() -> Void)?` — tight up. Maak het non-optional plus een `canRegenerate: Bool`; caller bepaalt zichtbaarheid.
- **L3** — Lege streaming bubbles krijgen nu `displayContent = " "` (space). Vervang door een dedicated `TypingIndicator` view (3 bouncing dots).
- **L5** — `ChatModelTests.swift`: voeg retry() tests toe voor `.notConfigured` en `.authentication` error states; verifieer dat retry niets doet bij niet-retryable errors.
- **L6** — `ChatView.swift`: body begint met een `Group { ... }` wrapper die niets doet. Weghalen.

### Niet in scope

- **H4** (per-call `HermesEndpoint`) — raakt `HermesClient` API en is Task 19 terrein. Naar `99-followups.md` #5.
- **L2** (UI string i18n consolidation) — project-wide, naar `99-followups.md`.
- **L4** (trailing newline `Text` stripping) — low-signal edge case, naar `99-followups.md`.
- **Files**: alles buiten `Features/Chat/*` en `Tests/HermesMacTests/ChatModelTests.swift`. In het bijzonder `Core/Networking/*` (Task 19), `DesignSystem/CodeHighlighter.swift` (Task 24).

## Implementation

### Files to modify

- `Sources/HermesMac/Features/Chat/ChatError.swift`
- `Sources/HermesMac/Features/Chat/ChatModel.swift`
- `Sources/HermesMac/Features/Chat/ChatView.swift`
- `Sources/HermesMac/Features/Chat/MessageBubbleView.swift`
- `Sources/HermesMac/Features/Chat/MessageComposerView.swift`
- `Sources/HermesMac/Features/Chat/CodeBlockView.swift`
- `Tests/HermesMacTests/ChatModelTests.swift`

### Approach

- **H1/M1**: probeer computed property eerst:

  ```swift
  public var messages: [MessageEntity] {
      conversation.messages.sorted { $0.createdAt < $1.createdAt }
  }
  ```

  Als iets in de view een `Binding` daarop eist of er is diff-animation state, fallback op een stored `@ObservationIgnored private var _messages` plus een `private func syncMessages() { _messages = conversation.messages.sorted(...) }` die na elke chunk append aangeroepen wordt. Test dat de view de updates ziet (`ChatModelTests`).

- **H2**: beide `Task { ... }` sites vervangen door `[weak self] in guard let self else { return }`.

- **H3**: `@Observable public final class ChatModel` — `public private(set) var chatError: ChatError?`. Nieuwe `public func dismissError() { chatError = nil }`. Grep door `Features/Chat/*.swift` voor directe writes en vervang.

- **M4**: `// @preconcurrency: Highlightr exposes non-Sendable NSAttributedString...` comment op dezelfde regel als (of direct boven) `@preconcurrency import Highlightr`.

- **M5**: simpel — `@State private var cachedHighlighted: NSAttributedString?` + `@State private var cacheKey: String?`. In `body`, als `cacheKey != currentKey`, recompute en cache. Of: verplaats de render in een subview `HighlightedCodeView: View, Equatable { ... }` met `static func == (lhs, rhs) -> Bool { lhs.key == rhs.key }` en wrap via `.equatable()`.

- **M6**: in de caller van `MessageComposerView`, wissel

  ```swift
  MessageComposerView(text: Binding(
      get: { model.inputText },
      set: { model.inputText = $0 }
  ))
  ```

  voor

  ```swift
  @Bindable var model = model
  MessageComposerView(text: $model.inputText)
  ```

## Verification

```
cd /Users/kiranknoppert/Documents/HermesMac/.claude/worktrees/task22-chat-hardening
swift build 2>&1 | tail -20
swift test --filter ChatModelTests 2>&1 | tail -30
```

Expected: build zonder warnings. ChatModelTests slagen incl. nieuwe retry-error tests. Existing tests blijven groen.

## Done when

- [ ] All High findings addressed (H1, H2, H3). H4 → followups.
- [ ] Medium findings addressed (M1–M6).
- [ ] Low findings (L1, L3, L5, L6) addressed. L2, L4 → followups.
- [ ] Nieuwe retry-error tests.
- [ ] `swift build` passes without warnings.
- [ ] `swift test` passes voor Chat suites.
- [ ] Self-review tegen de 6 /review skill categorieën — met bijzondere aandacht voor SwiftUI Quality (observation, view identity), Performance (animation scoping, highlightr caching) en Swift Best Practices (weak self in Tasks).
- [ ] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [ ] Conventional commit `fix(task22): chat feature hardening` op branch `fix/task22-chat-hardening`, met `file:line` referenties in body.
- [ ] Branch gepusht naar `origin`.
