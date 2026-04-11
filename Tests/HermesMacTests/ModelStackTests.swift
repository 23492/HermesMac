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

    @Test("versioned schema builds with correct identifier and model list")
    func versionedSchemaBuilds() throws {
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(SchemaV1.models.count == 2)

        // Migration plan references SchemaV1 with no stages
        #expect(HermesMigrationPlan.schemas.count == 1)
        #expect(HermesMigrationPlan.stages.isEmpty)

        // Container builds successfully with the versioned schema
        let container = try ModelStack.makeInMemoryContainer()
        #expect(container.schema.entities.count >= 2)
    }
}
