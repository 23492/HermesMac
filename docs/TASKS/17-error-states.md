# Task 17: Error states and retry UX

**Status:** ✅ Done
**Dependencies:** Task 08, Task 09
**Estimated effort:** 30 min

## Doel

Elke fout-scenario moet een duidelijke, actionable UI state hebben. Geen cryptische alerts, geen silent fails.

## Scope

### In scope

Scenario's en hun UX:

1. **Geen API key ingesteld** → Empty state met "Open Instellingen" knop
2. **Primary + local beide onbereikbaar** → Inline banner "Kan backend niet bereiken" + "Opnieuw proberen"
3. **401 Invalid API key** → Inline banner "Je API key klopt niet" + "Open Instellingen"
4. **Stream bekraapt halverwege** → Laat partial content staan, toon "Verbinding verbroken" banner + "Opnieuw proberen"
5. **Very slow response** → Na 15s zonder chunks toon "Nog bezig..." indicator naast spinner
6. **Empty conversation list** → "Geen chats nog. Tik op + om te beginnen."

### Niet in scope
- Offline queue (berichten verzenden zonder netwerk en syncen later)
- Automatic retries op non-idempotent calls

## Implementation

Enum voor views:

```swift
enum ChatViewState {
    case idle
    case streaming
    case needsConfiguration
    case networkError(String)
    case authenticationError
    case streamInterrupted(partial: String)
}
```

`ChatModel` moet deze state publiceren. `ChatView` rendert een match-expression op de state.

Retry logic in `ChatModel`:

```swift
public func retry() async {
    // Take the last user message and re-run the flow without creating a new entry
    guard let lastUser = messages.reversed().first(where: { $0.role == "user" }) else { return }
    // Build history from before the error
    // Resume streaming
}
```

## Done when

- [x] Alle 6 scenario's hebben een duidelijke UX
- [x] Retry knoppen werken
- [x] Empty state voor conversation list
- [x] Commit: `feat(task17): error states and retry UX`

## Completion notes

Commit: `dd5e40d`

Implementatie week op één punt af van de task spec: in plaats van een
flat `ChatViewState` enum ging ik voor een `ChatError` enum met drie
computed properties (`message`, `isRetryable`, `needsSettings`). Dat
houdt de ChatModel state simpel (twee bools + één optionele error)
zonder dat de view elke scenario apart hoeft uit te pakken — de banner
leest gewoon `error.isRetryable` en `error.needsSettings` voor de
knoppen. De zes scenario's mappen nu op:

1. **Geen API key** → `ChatError.notConfigured` + `noApiKeyEmptyState`
   overlay in ChatView + `needsConfigurationState` in RootView detail
2. **Backend onbereikbaar** → `ChatError.network(detail)` met "Opnieuw
   proberen" banner
3. **401 Invalid key** → `ChatError.authentication` met "Open
   Instellingen" banner
4. **Stream onderbroken** → `ChatError.streamInterrupted` met "Opnieuw
   proberen", partial content blijft staan
5. **Slow reply** → `slowReply` bool, flipped na 15s zonder chunks,
   getoond als ultraThinMaterial banner boven de composer
6. **Empty conversation list** → `emptyListOverlay` op de List

De `retry()` methode drops een trailing assistant message (empty
placeholder van een gefaalde send of partial content van een
streamInterrupted) en start opnieuw vanaf de laatste user message.

De `categorise(_:receivedAnyChunk:)` helper mapt `HermesError` naar
`ChatError`: `.transport` → `.network` of `.streamInterrupted`
afhankelijk van of de stream al chunks had ontvangen; `401` →
`.authentication`; `.notAuthenticated` → `.notConfigured`.

Tests: 8 nieuwe ChatModelTests voor retry state machine en ChatError
semantics. Suite 21/21 op ChatModel, 34/35 overall (pre-existing
HermesClient listModels 401 flake).

Build verified: `swift build` clean op Swift 6 strict concurrency,
geen warnings.
