# Task 32: Mid-stream save + per-call endpoint + .inStream UX (#3, #7, #12)

**Status:** Open (Phase 2 — na Phase 1 merge)
**Branch:** `fix/task32-chat-robustness`
**Followups:** #3, #7, #12

## Doel

Maak de chat ervaring robuuster: mid-stream saves, per-call endpoints, en betere error UX.

## Implementatie volgorde

### 1. #7 (per-call endpoint) — meest structureel, eerst doen

- `HermesClient`: voeg `endpoint: HermesEndpoint` parameter toe aan `streamChatCompletion(request:endpoint:)` en `listModels(endpoint:)`
- Deprecate `setEndpoint()` of verwijder het (pre-release, geen backwards compat nodig)
- `ChatModel.performStreaming()`: bouw `HermesEndpoint` en geef direct door in plaats van `await client.setEndpoint(endpoint)`

### 2. #3 (mid-stream save) — bouwt voort op de streaming loop

- Voeg debounced `repository.save()` call toe in de `for try await chunk in stream` loop (elke 2 seconden of elke 20 chunks, wat eerder komt)
- Handle save errors graceful (log, niet de stream onderbreken)
- Voeg `ConversationRepository.saveContext()` helper toe indien nodig

### 3. #12 (.inStream error UX) — verfijn error presentatie

- Evalueer of huidige mapping (`.inStream → .streamInterrupted / .other`) voldoende is
- Als distinct UX nodig: voeg `ChatError.backendError(String)` case toe met eigen icon/copy in `ChatView`
- Als huidige mapping OK is: documenteer de beslissing en sluit #12

## Files owned (exclusief)

- `Sources/HermesMac/Features/Chat/ChatModel.swift`
- `Sources/HermesMac/Features/Chat/ChatError.swift`
- `Sources/HermesMac/Features/Chat/ChatView.swift`
- `Sources/HermesMac/Core/Networking/HermesClient.swift`
- `Sources/HermesMac/Core/Persistence/ConversationRepository.swift`
- `Tests/HermesMacTests/ChatModelTests.swift`

## Acceptatiecriteria

- `streamChatCompletion` en `listModels` accepteren een `endpoint` parameter
- `setEndpoint()` is verwijderd of deprecated
- Mid-stream save werkt met debounce
- .inStream error UX is geadresseerd (fix of gedocumenteerde beslissing)
