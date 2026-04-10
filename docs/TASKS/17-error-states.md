# Task 17: Error states and retry UX

**Status:** Niet gestart
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

- [ ] Alle 6 scenario's hebben een duidelijke UX
- [ ] Retry knoppen werken
- [ ] Empty state voor conversation list
- [ ] Commit: `feat(task17): error states and retry UX`
