# Task 33: MessageEntity.role String -> enum promotie (#14)

**Status:** Open (Phase 3 — na Phase 2 merge)
**Branch:** `fix/task33-role-enum`
**Followup:** #14

## Doel

Promoveer `MessageEntity.role` van `String` naar `MessageRole` enum door het hele project.

## Wat te doen

1. Vervang alle `role == "user"` / `role == "assistant"` string vergelijkingen met `roleEnum == .user` / `.assistant`
2. Converteer `appendMessage(role: String, ...)` callsites naar de typed `appendMessage(role: MessageRole, ...)` overload
3. Verander `MessageEntity.role` stored property van `String` naar `MessageRole` (pre-release, geen migratie nodig)
4. Update alle test files die raw role strings gebruiken

## Files owned (exclusief)

- `Sources/HermesMac/Core/Persistence/MessageEntity.swift`
- `Sources/HermesMac/Core/Persistence/ConversationRepository.swift`
- `Sources/HermesMac/Features/Chat/ChatModel.swift`
- `Sources/HermesMac/Features/Chat/ChatView.swift`
- `Sources/HermesMac/Features/Chat/MessageBubbleView.swift`
- `Tests/HermesMacTests/ChatModelTests.swift`
- `Tests/HermesMacTests/ConversationRepositoryTests.swift`
- `Tests/HermesMacTests/ModelStackTests.swift`

## Acceptatiecriteria

- Geen `role == "user"` of `role == "assistant"` string vergelijkingen meer in de codebase
- `MessageEntity.role` is van type `MessageRole` (niet meer `String`)
- Alle `appendMessage` calls gebruiken de typed overload
- Alle tests geupdate en correct
