# Task 20: persistence correctness

**Status:** Niet gestart
**Dependencies:** Task 17 (error states — shipped)
**Estimated effort:** 45–60 min

## Doel

SwiftData persistence-laag correct maken: geen triple-wired relationships, consistente foutafhandeling via typed errors, en proper doc comments.

## Context

Code review van 2026-04-11 leverde in de Persistence-module 2 High, 5 Medium en 6 Low findings op. Deze task pakt **alleen** `ConversationEntity`, `MessageEntity` en `ConversationRepository` aan. `ModelStack.swift` is expliciet van Task 23 (de app-shell agent die ook `LaunchView` en error recovery raakt). `ChatModel.swift` (mid-stream save strategy, H2) is van Task 22.

Deze task loopt **parallel** met Tasks 19, 21–24.

## Scope

### In scope

**High**
- **H1** — `ConversationRepository.appendMessage`: de methode wire-t de relationship driedubbel (`message.conversation = conversation`, `conversation.messages.append(message)` en `context.insert`). Simplify naar de single-source: set `message.conversation = conversation`; SwiftData doet de rest. Test dat `conversation.messages` de nieuwe message bevat na save.

**Medium**
- **M1** — `ConversationRepository.delete(message:)`: handmatige removal uit `conversation.messages` — weghalen, vertrouwen op cascade via inverse relationship.
- **M5** — Nieuwe `enum ConversationRepositoryError: LocalizedError { case fetchFailed(underlying: Error), saveFailed(underlying: Error), notFound }`. Alle repo methodes gooien deze in plaats van raw SwiftData errors.

**Low**
- **L1** — De Dutch default title `"Nieuwe chat"` verhuist uit `ConversationEntity.init` naar de repository, via `String(localized: "chat.default.title", defaultValue: "Nieuwe chat")`. Entity blijft locale-agnostic.
- **L3** — `role: String` → `enum MessageRole: String, Codable { case user, assistant, system, tool }`. Nog geen migratie nodig (pre-release).
- **L5** — `///` doc comments op alle public members van `ConversationEntity`, `MessageEntity`, `ConversationRepository`.
- **L6** — Nieuwe tests in `ConversationRepositoryTests`: `touch(_:)` updatet `updatedAt`, `delete(message:)` verwijdert uit parent, cascade delete op conversation, `listAllSorted` geeft stabiele volgorde.

### Niet in scope

- **H2** (mid-stream save strategy) — raakt `ChatModel.swift` → Task 22 terrein, naar `99-followups.md`.
- **M2** (empty-conversation pruning) — product decision, naar `99-followups.md`.
- **M3** (schema versioning + migration) — voor TestFlight, naar `99-followups.md`.
- **M4** (prefetch relationships) — pas nodig als sidebar message-preview toont, naar `99-followups.md`.
- **L4** (`ModelStack.fatalError` logging) — hoort bij Task 23's `ModelStack` werk.
- **Files**: `ModelStack.swift` (Task 23), `ChatModel.swift` (Task 22), alles in `Features/` (Task 22 of 23), alles in `Core/Networking/` of `Core/Settings/` (Tasks 19 en 21).

## Implementation

### Files to modify

- `Sources/HermesMac/Core/Persistence/ConversationEntity.swift`
- `Sources/HermesMac/Core/Persistence/MessageEntity.swift`
- `Sources/HermesMac/Core/Persistence/ConversationRepository.swift`
- `Tests/HermesMacTests/ConversationRepositoryTests.swift`

### Approach

Per finding:

- **H1**: in `appendMessage(_:to:)` verwijder de `conversation.messages.append(...)` call en `context.insert(message)`, houd alleen `message.conversation = conversation`. SwiftData's `@Relationship` zorgt voor inverse. Test breidt bestaande test uit: na save, fetch de conversation uit een nieuwe context, assert `messages.count == 1`.
- **M1**: in `delete(message:)` weg met `if let idx = conversation.messages.firstIndex(...) { conversation.messages.remove(at: idx) }`. Laat `context.delete(message)` staan.
- **M5**: nieuwe file-scoped `enum ConversationRepositoryError: LocalizedError` onderaan `ConversationRepository.swift`. Wrap `try context.save()` in `do/catch { throw .saveFailed(underlying: error) }`. `errorDescription` in het Nederlands zoals de rest van user-facing strings.
- **L1**: verwijder de default argument `title: String = "Nieuwe chat"` in `ConversationEntity.init` zodat caller expliciet een titel meegeeft. In `ConversationRepository.createConversation()` gebruik `String(localized: "chat.default.title", defaultValue: "Nieuwe chat")`.
- **L3**: nieuwe `enum MessageRole: String, Codable, Sendable { case user, assistant, system, tool }`. In `MessageEntity` verander `var role: String` naar `var role: MessageRole`. Update `ConversationRepository.appendMessage` signature. Update tests.
- **L5**: elke public member krijgt `///` doc comment, leg uit wat de relationship garandeert (unidirectional write via `conversation`).
- **L6**: Swift Testing tests:
  - `@Test func touchUpdatesTimestamp() async throws`
  - `@Test func deleteMessageRemovesFromParent() async throws`
  - `@Test func deleteConversationCascadesToMessages() async throws`
  - `@Test func listAllSortedByUpdatedAtDescending() async throws`

## Verification

```
cd /Users/kiranknoppert/Documents/HermesMac/.claude/worktrees/task20-persistence
swift build 2>&1 | tail -20
swift test --filter ConversationRepositoryTests 2>&1 | tail -30
```

Expected: build zonder nieuwe warnings. Nieuwe tests slagen. Bestaande tests blijven slagen.

## Done when

- [ ] H1 en alle Medium findings in scope zijn gefixt.
- [ ] Low findings (L1, L3, L5, L6) addressed.
- [ ] Out-of-scope findings gelogd in `99-followups.md` als nog niet aanwezig.
- [ ] Nieuwe tests geschreven en slagen.
- [ ] `swift build` passes without warnings.
- [ ] `swift test` passes voor persistence suites.
- [ ] Self-review tegen de 6 /review skill categorieën.
- [ ] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [ ] Conventional commit `fix(task20): persistence correctness` op branch `fix/task20-persistence`, met `file:line` referenties in body.
- [ ] Branch gepusht naar `origin`.
