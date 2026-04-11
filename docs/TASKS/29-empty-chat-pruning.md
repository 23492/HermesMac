# Task 29: Empty chat pruning (#5)

**Status:** Open
**Branch:** `fix/task29-empty-chat-pruning`
**Followup:** #5

## Doel

Voorkom dat lege "Nieuwe chat" conversaties zich opstapelen in de sidebar.

## Product beslissing

Prune-on-create: wanneer de user op "Nieuwe chat" drukt, verwijder alle bestaande conversaties met nul berichten voordat de nieuwe aangemaakt wordt. Sidebar updatet automatisch via `@Query`.

## Wat te doen

1. Voeg `pruneEmpty(excluding:)` toe aan `ConversationRepository` — verwijdert conversaties waar `messages.isEmpty`, exclusief een gegeven ID
2. Roep `pruneEmpty(excluding: newConversation.id)` aan in `RootView.createNewChat()` direct na `repo.create()`
3. Voeg test toe in `ConversationRepositoryTests.swift` voor het pruning gedrag

## Files owned (exclusief)

- `Sources/HermesMac/Core/Persistence/ConversationRepository.swift`
- `Sources/HermesMac/Features/Root/RootView.swift`
- `Sources/HermesMac/Features/Sidebar/ConversationListView.swift`
- `Tests/HermesMacTests/ConversationRepositoryTests.swift`

## Acceptatiecriteria

- Lege conversaties worden verwijderd bij het aanmaken van een nieuwe chat
- De huidige (net aangemaakte) conversatie wordt niet verwijderd
- Conversaties met berichten worden niet aangeraakt
- Test verifieert pruning gedrag
