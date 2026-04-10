# Task 06: SwiftData models + ModelStack ✅ Done

**Status:** Done
**Dependencies:** Task 00
**Estimated effort:** 25 min

## Doel

Definieer `ConversationEntity` en `MessageEntity` als `@Model` classes en zet een `ModelContainer` op die de app kan gebruiken.

## Scope

### In scope
- `Sources/HermesMac/Core/Persistence/ConversationEntity.swift`
- `Sources/HermesMac/Core/Persistence/MessageEntity.swift`
- `Sources/HermesMac/Core/Persistence/ModelStack.swift` — factory voor ModelContainer
- `Tests/HermesMacTests/ModelStackTests.swift` — een basic test die insert + fetch doet met in-memory container

### Niet in scope
- Migraties (v1 schema, niks om te migreren)
- CloudKit sync
- Tool calls of reasoning storage

## Implementation

**`ConversationEntity.swift`**:

```swift
import Foundation
import SwiftData

@Model
public final class ConversationEntity {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var model: String
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.conversation)
    public var messages: [MessageEntity]

    public init(
        id: UUID = UUID(),
        title: String = "Nieuwe chat",
        model: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.messages = []
    }
}
```

**`MessageEntity.swift`**:

```swift
import Foundation
import SwiftData

@Model
public final class MessageEntity {
    @Attribute(.unique) public var id: UUID
    public var role: String
    public var content: String
    public var createdAt: Date
    public var conversation: ConversationEntity?

    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        createdAt: Date = Date(),
        conversation: ConversationEntity? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.conversation = conversation
    }
}
```

**`ModelStack.swift`**:

```swift
import Foundation
import SwiftData

public enum ModelStack {

    /// Shared app container. Fatal error on failure — this is unrecoverable.
    @MainActor
    public static let shared: ModelContainer = {
        do {
            let schema = Schema([ConversationEntity.self, MessageEntity.self])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// In-memory container for previews and tests.
    @MainActor
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ConversationEntity.self, MessageEntity.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

## Tests

```swift
import Testing
import SwiftData
@testable import HermesMac

@Suite("ModelStack")
@MainActor
struct ModelStackTests {

    @Test("insert and fetch a conversation")
    func insertAndFetch() throws {
        let container = try ModelStack.makeInMemoryContainer()
        let ctx = ModelContext(container)

        let conv = ConversationEntity(model: "hermes-agent")
        ctx.insert(conv)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<ConversationEntity>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.model == "hermes-agent")
    }

    @Test("cascade delete removes messages")
    func cascadeDelete() throws {
        let container = try ModelStack.makeInMemoryContainer()
        let ctx = ModelContext(container)

        let conv = ConversationEntity(model: "hermes-agent")
        let msg = MessageEntity(role: "user", content: "hi", conversation: conv)
        conv.messages.append(msg)
        ctx.insert(conv)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).count == 1)

        ctx.delete(conv)
        try ctx.save()

        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).isEmpty)
    }
}
```

## Done when

- [x] Drie persistence files aangemaakt
- [ ] 2 tests passen (op Mac; op Linux zonder SwiftData is dit skippable)
- [x] Commit: `feat(task06): SwiftData conversation and message models`

## Completion notes

**Date:** 2026-04-10
**Commit:** eae7b01

Drie persistence files aangemaakt exact volgens spec: ConversationEntity, MessageEntity, ModelStack. Tests geschreven maar niet geverifieerd op Linux (SwiftData is Apple-only). Build niet geverifieerd op Linux, moet op Mac getest worden.
