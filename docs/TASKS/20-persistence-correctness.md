# Task 20: persistence correctness ✅ Done

**Status:** Done
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

- [x] H1 en alle Medium findings in scope zijn gefixt.
- [x] Low findings (L1, L3, L5, L6) addressed.
- [x] Out-of-scope findings gelogd in `99-followups.md` als nog niet aanwezig.
- [x] Nieuwe tests geschreven en slagen.
- [x] `swift build` passes without warnings.
- [x] `swift test` passes voor persistence suites.
- [x] Self-review tegen de 6 /review skill categorieën.
- [x] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [x] Conventional commit `fix(task20): persistence correctness` op branch `fix/task20-persistence`, met `file:line` referenties in body.
- [x] Branch gepusht naar `origin`.

## Completion notes

**Date:** 2026-04-11
**Commit:** (see git log — filled in at commit time)
**Branch:** `fix/task20-persistence`
**Build:** `swift build` clean, no warnings.
**Tests:** `swift test --filter ConversationRepositoryTests` — 11/11 pass
(was 5 baseline). Full suite: 48/49 pass; the 1 failure is the pre-existing
`HermesClientTests "listModels maps 401" faalt` flaky test logged as
followup #2 — unrelated to this task.

### Per-finding notes

**H1 — `appendMessage` triple-wires relationship** (was
`ConversationRepository.swift:43-52`, fix at `:195-208`)

The old code built a `MessageEntity` with `conversation: conversation`,
then also did `conversation.messages.append(message)` *and*
`context.insert(message)`. That's three writes for the same edge: one
via the inverse on init, one via the parent's array, one via a context
insert. SwiftData's change tracking gets confused by this — observation
of the parent's array could double-fire and inserts could race with
cascade bookkeeping in subtle ways.

The fix is the "one true write path": just set
`message.conversation = conversation` during `MessageEntity.init`.
SwiftData's `@Relationship(inverse:)` populates `conversation.messages`
automatically and the child is auto-inserted into the parent's context.
No `append`, no `insert`. Proven by the new test
`appendMessage wires relationship and persists via a single source`
which re-fetches the conversation through the context and asserts
the stored relationship count is exactly 1.

**M1 — `delete(message:)` manually removes from parent** (was
`ConversationRepository.swift:63-70`, fix at `:135-139`)

The old code did `conversation.messages.removeAll { $0.id == message.id }`
before `context.delete(message)`. That's the same class of bug as H1:
the inverse relationship already handles the parent array update; doing
it manually is a redundant mutation that competes with SwiftData's
change propagation. Removed. We still bump the parent's `updatedAt` so
the sidebar re-sorts after a message deletion. Covered by new test
`delete(message:) removes the message from its parent`.

**M5 — Introduce `ConversationRepositoryError` enum** (new type at
`ConversationRepository.swift:10-31`)

New `enum ConversationRepositoryError: Error, LocalizedError, Sendable`
with cases `.fetchFailed(underlying: String)`, `.saveFailed(underlying:
String)`, and `.notFound`. Every repo method now wraps raw SwiftData
errors in one of these cases via a private `save()` helper
(`:241-249`) or a `do/catch` block around `context.fetch` (`:80-86`).
`errorDescription` is Dutch (matches the rest of the user-facing copy).
Sendable so the errors can cross actor boundaries. Covered by new test
`ConversationRepositoryError supplies Dutch user-facing descriptions`.
The `underlying` field takes a `String` rather than an `Error` so the
enum stays `Sendable` without wrapping non-Sendable `NSError` values.

**L1 — Move Dutch default title out of `ConversationEntity.init`**
(entity at `ConversationEntity.swift:59-71`, repository at
`ConversationRepository.swift:102-111` and `:251-260`)

The entity initialiser no longer embeds the Dutch `"Nieuwe chat"`
literal. `ConversationEntity.init` now defaults `title` to `""` so it
stays strictly locale-agnostic. `ConversationRepository.create(model:)`
supplies the localised default via
`String(localized: "chat.default.title", defaultValue: "Nieuwe chat",
comment: ...)` through a `private static var defaultConversationTitle`
helper. This also centralises the user-facing string in one place.

Deviation from the letter of the spec: the spec suggested removing the
default argument entirely so callers must pass a title explicitly. I
kept an empty-string default because `Tests/HermesMacTests/ModelStackTests.swift`
(owned by Task 23 — read-only for me) still calls
`ConversationEntity(model: "hermes-agent")` without a title. Empty
string satisfies the "locale-agnostic" requirement without breaking
Task 23's test build.

**L3 — Promote `role: String` → `MessageRole` enum** (enum at
`MessageEntity.swift:17-22`, typed init at `:104-118`, typed repository
overload at `ConversationRepository.swift:225-235`)

Partial implementation documented as followup #8. The enum itself is
added (`MessageRole: String, Codable, Sendable, CaseIterable`) along
with a typed `MessageEntity.convenience init`, a `roleEnum` computed
accessor (`MessageEntity.swift:63-65`) and a typed `appendMessage`
overload on the repository. What is deliberately *not* changed is the
stored property type on `MessageEntity` — it stays `var role: String`
because changing the storage cascades into `Features/Chat/ChatModel.swift`,
`Features/Chat/ChatView.swift`, `Features/Chat/MessageBubbleView.swift`,
`Tests/HermesMacTests/ChatModelTests.swift` and
`Tests/HermesMacTests/ModelStackTests.swift` — all files owned by
Task 22 or Task 23. A full storage promotion needs coordinated updates
across those files and is deferred to a post-merge followup (entry #8
in `99-followups.md`). Task 20 delivers the type and new call-site
entry points; the promotion itself is a future mechanical edit.

**L5 — Doc comments on all public members**

Every public declaration in `ConversationEntity.swift`, `MessageEntity.swift`,
and `ConversationRepository.swift` has a `///` doc comment. The entity
docs explicitly call out the "set `message.conversation = conversation`
and nothing else" rule so future readers don't re-introduce H1.
`ConversationRepositoryError` has case-level docs. The repository has a
file-level threading note. File lengths are well under the 400-line
limit (261 max).

**L6 — New tests**

Added 6 tests in `Tests/HermesMacTests/ConversationRepositoryTests.swift`:

- `touch(_:) bumps updatedAt without changing other fields` — verifies
  the new single-purpose `touch` helper.
- `delete(message:) removes the message from its parent` — guards the
  M1 fix; checks the inverse relationship updates the parent array.
- `delete cascades to messages via SwiftData relationship` — guards the
  cascade rule; deletes a parent with 3 messages and asserts the store
  is empty afterwards.
- `listAll ordering is stable for equal updatedAt timestamps` —
  guards the `SortDescriptor(\.id)` secondary sort.
- `appendMessage typed overload forwards to the string path` — covers
  the new `MessageRole` overload across all 4 cases.
- `ConversationRepositoryError supplies Dutch user-facing descriptions`
  — covers the new error type.

Plus upgraded the existing `appendMessage wires relationship and
persists via a single source` test to re-fetch through the context and
assert the stored relationship count is 1 (the meaningful H1 check).

### Out of scope — logged in 99-followups.md

- #3 — H2 mid-stream save strategy (Task 22 territory)
- #4 — M2 empty-conversation pruning (product decision)
- #5 — M3 schema versioning for SwiftData (pre-TestFlight task)
- #6 — M4 prefetch relationships (only needed when sidebar shows message preview)
- #7 — L4 ModelStack fatalError logging (Task 23 territory)
- #8 — L3 stored-type promotion (needs Task 22 + 20 merge coordination)

### Self-review against /review skill's 6 categories

1. **Swift Best Practices**: `@MainActor` isolation matches project
   concurrency policy, `Sendable` error enum, explicit access control,
   no force unwraps, verb-based naming, typed errors, `final class`.
2. **SwiftUI Quality**: N/A — pure persistence layer, no views.
3. **Performance**: `listAll` fetch descriptor is cheap and has a
   deterministic secondary sort; no heavy work, no unnecessary
   reference-type retain cycles.
4. **Security & Safety**: No force unwraps, no sensitive data in logs,
   error messages are local (SwiftData failures, not user secrets).
5. **Architecture**: Clean Entity / Error / Repository separation;
   user-facing strings live only in the repository; doc comments
   describe the relationship-wiring contract explicitly; files are
   well under the 400-line budget.
6. **Project-Specific Standards (CLAUDE.md)**: Swift 6 strict
   concurrency compiles, `@Observable` N/A here, no force unwraps,
   files < 400 lines, doc comments on public, user-facing strings in
   Dutch (errorDescription + localised default title), code comments
   in English.

No in-scope smells found during self-review.
