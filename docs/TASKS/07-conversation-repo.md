# Task 07: ConversationRepository

**Status:** Niet gestart
**Dependencies:** Task 06
**Estimated effort:** 20 min

## Doel

Een simpele `@MainActor` repository die CRUD op conversations doet. Geen abstracties, geen protocols, geen dependency injection magie. Gewoon een class die een ModelContext vasthoudt.

## Scope

### In scope
- `Sources/HermesMac/Core/Persistence/ConversationRepository.swift`
- Methods: `listAll()`, `create(model:)`, `delete(_:)`, `appendMessage(_:to:)`
- `Tests/HermesMacTests/ConversationRepositoryTests.swift`

### Niet in scope
- Zoeken (later)
- Pagination
- Tagging of folders

## Implementation

```swift
import Foundation
import SwiftData

@MainActor
public final class ConversationRepository {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// All conversations sorted by updatedAt descending.
    public func listAll() throws -> [ConversationEntity] {
        var descriptor = FetchDescriptor<ConversationEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Create a new empty conversation with the given model.
    @discardableResult
    public func create(model: String) throws -> ConversationEntity {
        let conversation = ConversationEntity(model: model)
        context.insert(conversation)
        try context.save()
        return conversation
    }

    /// Delete a conversation and all its messages.
    public func delete(_ conversation: ConversationEntity) throws {
        context.delete(conversation)
        try context.save()
    }

    /// Append a message to a conversation and touch its updatedAt.
    public func appendMessage(
        role: String,
        content: String,
        to conversation: ConversationEntity
    ) throws -> MessageEntity {
        let message = MessageEntity(
            role: role,
            content: content,
            conversation: conversation
        )
        conversation.messages.append(message)
        conversation.updatedAt = Date()
        context.insert(message)
        try context.save()
        return message
    }

    /// Update the title of a conversation.
    public func updateTitle(_ title: String, for conversation: ConversationEntity) throws {
        conversation.title = title
        conversation.updatedAt = Date()
        try context.save()
    }
}
```

## Tests

Test dat create, append, delete en listAll correct werken, en dat updatedAt wordt aangeraakt bij append.

## Done when

- [ ] Repository bestaat
- [ ] 4+ tests passen
- [ ] Commit: `feat(task07): ConversationRepository with basic CRUD`
