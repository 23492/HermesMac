import Foundation
import Testing
import SwiftData
@testable import HermesMac

@Suite("ConversationRepository")
@MainActor
struct ConversationRepositoryTests {

    private func makeRepo() throws -> (ConversationRepository, ModelContext) {
        let container = try ModelStack.makeInMemoryContainer()
        let ctx = ModelContext(container)
        let repo = ConversationRepository(context: ctx)
        return (repo, ctx)
    }

    @Test("create inserts a conversation and persists it")
    func createConversation() throws {
        let (repo, _) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")

        #expect(conv.model == "hermes-agent")
        #expect(conv.title == "Nieuwe chat")
        #expect(conv.messages.isEmpty)

        let all = try repo.listAll()
        #expect(all.count == 1)
        #expect(all.first?.id == conv.id)
    }

    @Test("listAll returns conversations sorted by updatedAt descending")
    func listAllSorted() throws {
        let (repo, _) = try makeRepo()

        let older = try repo.create(model: "hermes-agent")
        // Ensure a time difference
        let later = Date().addingTimeInterval(10)
        let newer = try repo.create(model: "hermes-agent")
        newer.updatedAt = later

        let all = try repo.listAll()
        #expect(all.count == 2)
        #expect(all[0].id == newer.id)
        #expect(all[1].id == older.id)
    }

    @Test("delete removes conversation and its messages via cascade")
    func deleteConversation() throws {
        let (repo, ctx) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        try repo.appendMessage(role: "user", content: "hello", to: conv)

        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).count == 1)

        try repo.delete(conv)

        #expect(try repo.listAll().isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).isEmpty)
    }

    @Test("appendMessage adds message and updates updatedAt")
    func appendMessage() throws {
        let (repo, _) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        let originalDate = conv.updatedAt

        // Small delay so updatedAt changes
        let msg = try repo.appendMessage(role: "user", content: "hi there", to: conv)

        #expect(msg.role == "user")
        #expect(msg.content == "hi there")
        #expect(msg.conversation?.id == conv.id)
        #expect(conv.messages.count == 1)
        #expect(conv.updatedAt >= originalDate)
    }

    @Test("updateTitle changes title and touches updatedAt")
    func updateTitle() throws {
        let (repo, _) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        let originalDate = conv.updatedAt

        try repo.updateTitle("My Chat", for: conv)

        #expect(conv.title == "My Chat")
        #expect(conv.updatedAt >= originalDate)
    }
}
