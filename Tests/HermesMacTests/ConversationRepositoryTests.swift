import Foundation
import Testing
import SwiftData
@testable import HermesMac

@Suite("ConversationRepository")
@MainActor
struct ConversationRepositoryTests {

    // MARK: - Helpers

    private func makeRepo() throws -> (ConversationRepository, ModelContext) {
        let container = try ModelStack.makeInMemoryContainer()
        let ctx = ModelContext(container)
        let repo = ConversationRepository(context: ctx)
        return (repo, ctx)
    }

    // MARK: - Create

    @Test("create inserts a conversation with localised default title")
    func createConversation() throws {
        let (repo, _) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")

        #expect(conv.model == "hermes-agent")
        // Repository supplies the localised default; entity itself is
        // locale-agnostic.
        #expect(conv.title == "Nieuwe chat")
        #expect(conv.messages.isEmpty)

        let all = try repo.listAll()
        #expect(all.count == 1)
        #expect(all.first?.id == conv.id)
    }

    // MARK: - List sort

    @Test("listAll returns conversations sorted by updatedAt descending")
    func listAllSorted() throws {
        let (repo, _) = try makeRepo()

        let older = try repo.create(model: "hermes-agent")
        let newer = try repo.create(model: "hermes-agent")
        // Force a deterministic ordering — the test should not rely on
        // wall-clock precision.
        newer.updatedAt = Date().addingTimeInterval(10)

        let all = try repo.listAll()
        #expect(all.count == 2)
        #expect(all[0].id == newer.id)
        #expect(all[1].id == older.id)
    }

    @Test("listAll ordering is stable for equal updatedAt timestamps")
    func listAllSortedStable() throws {
        let (repo, _) = try makeRepo()

        let anchor = Date()
        let first = try repo.create(model: "hermes-agent")
        let second = try repo.create(model: "hermes-agent")
        let third = try repo.create(model: "hermes-agent")

        // Collapse all timestamps to the same value; the secondary id sort
        // guarantees a deterministic order regardless of insertion order.
        first.updatedAt = anchor
        second.updatedAt = anchor
        third.updatedAt = anchor

        let run1 = try repo.listAll().map(\.id)
        let run2 = try repo.listAll().map(\.id)

        #expect(run1 == run2)
        #expect(run1.count == 3)
    }

    // MARK: - Delete

    @Test("delete removes conversation and its messages via cascade")
    func deleteConversation() throws {
        let (repo, ctx) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        try repo.appendMessage(role: .user, content: "hello", to: conv)

        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).count == 1)

        try repo.delete(conv)

        #expect(try repo.listAll().isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).isEmpty)
    }

    @Test("delete(message:) removes the message from its parent")
    func deleteMessageRemovesFromParent() throws {
        let (repo, ctx) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        let first = try repo.appendMessage(role: .user, content: "one", to: conv)
        let second = try repo.appendMessage(role: .assistant, content: "two", to: conv)

        #expect(conv.messages.count == 2)

        try repo.delete(message: first)

        // Parent's messages array reflects the removal via the inverse
        // relationship — no manual `removeAll` in the repository.
        #expect(conv.messages.count == 1)
        #expect(conv.messages.first?.id == second.id)

        let remaining = try ctx.fetch(FetchDescriptor<MessageEntity>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == second.id)
    }

    @Test("delete cascades to messages via SwiftData relationship")
    func deleteConversationCascadesToMessages() throws {
        let (repo, ctx) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        try repo.appendMessage(role: .user, content: "a", to: conv)
        try repo.appendMessage(role: .assistant, content: "b", to: conv)
        try repo.appendMessage(role: .user, content: "c", to: conv)

        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).count == 3)

        try repo.delete(conv)

        #expect(try ctx.fetch(FetchDescriptor<MessageEntity>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<ConversationEntity>()).isEmpty)
    }

    // MARK: - Append

    @Test("appendMessage wires relationship and persists via a single source")
    func appendMessage() throws {
        let (repo, ctx) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        let originalUpdatedAt = conv.updatedAt

        let msg = try repo.appendMessage(role: .user, content: "hi there", to: conv)

        #expect(msg.role == .user)
        #expect(msg.content == "hi there")
        #expect(msg.conversation?.id == conv.id)
        #expect(conv.messages.count == 1)
        #expect(conv.messages.first?.id == msg.id)
        #expect(conv.updatedAt >= originalUpdatedAt)

        // Re-fetch through the context to prove the relationship is
        // persisted, not just stitched together in the in-memory object
        // graph. The bug we're guarding against (H1) used to triple-wire
        // and still produced a stored row, so the relationship assertion
        // is the meaningful check here.
        let fetched = try ctx.fetch(FetchDescriptor<ConversationEntity>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.messages.count == 1)
        #expect(fetched.first?.messages.first?.id == msg.id)
    }

    @Test("appendMessage stores typed MessageRole values for all cases")
    func appendMessageTypedOverload() throws {
        let (repo, _) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")

        let userMsg = try repo.appendMessage(role: .user, content: "u", to: conv)
        let assistantMsg = try repo.appendMessage(role: .assistant, content: "a", to: conv)
        let systemMsg = try repo.appendMessage(role: .system, content: "s", to: conv)
        let toolMsg = try repo.appendMessage(role: .tool, content: "t", to: conv)

        #expect(userMsg.role == .user)
        #expect(assistantMsg.role == .assistant)
        #expect(systemMsg.role == .system)
        #expect(toolMsg.role == .tool)
        #expect(conv.messages.count == 4)
    }

    // MARK: - Update

    @Test("updateTitle changes title and touches updatedAt")
    func updateTitle() throws {
        let (repo, _) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        let originalDate = conv.updatedAt

        try repo.updateTitle("My Chat", for: conv)

        #expect(conv.title == "My Chat")
        #expect(conv.updatedAt >= originalDate)
    }

    @Test("touch(_:) bumps updatedAt without changing other fields")
    func touchUpdatesTimestamp() throws {
        let (repo, _) = try makeRepo()

        let conv = try repo.create(model: "hermes-agent")
        let originalTitle = conv.title
        let originalModel = conv.model
        let originalCreatedAt = conv.createdAt
        // Push updatedAt into the past so any increment is observable even
        // if the test runs in less than a millisecond.
        conv.updatedAt = Date().addingTimeInterval(-60)
        let beforeTouch = conv.updatedAt

        try repo.touch(conv)

        #expect(conv.updatedAt > beforeTouch)
        #expect(conv.title == originalTitle)
        #expect(conv.model == originalModel)
        #expect(conv.createdAt == originalCreatedAt)
    }

    // MARK: - Prune empty

    @Test("pruneEmpty removes empty conversations except the excluded one")
    func pruneEmptyRemovesEmptyConversations() throws {
        let (repo, _) = try makeRepo()

        // Create three conversations: one with messages, two empty.
        let withMessages = try repo.create(model: "hermes-agent")
        try repo.appendMessage(role: .user, content: "hello", to: withMessages)

        let emptyKept = try repo.create(model: "hermes-agent")
        let emptyRemoved = try repo.create(model: "hermes-agent")

        #expect(try repo.listAll().count == 3)

        // Prune, excluding emptyKept.
        repo.pruneEmpty(excluding: emptyKept.id)

        let remaining = try repo.listAll()
        let remainingIDs = Set(remaining.map(\.id))

        // The conversation with messages survives.
        #expect(remainingIDs.contains(withMessages.id))
        // The excluded empty conversation survives.
        #expect(remainingIDs.contains(emptyKept.id))
        // The other empty conversation is deleted.
        #expect(!remainingIDs.contains(emptyRemoved.id))
        #expect(remaining.count == 2)
    }

    // MARK: - Error wrapping

    @Test("ConversationRepositoryError supplies Dutch user-facing descriptions")
    func errorDescriptionsAreLocalised() {
        let fetchError = ConversationRepositoryError.fetchFailed(underlying: "db gone")
        #expect(fetchError.errorDescription?.contains("ophalen") == true)

        let saveError = ConversationRepositoryError.saveFailed(underlying: "disk full")
        #expect(saveError.errorDescription?.contains("Opslaan") == true)

        let notFound = ConversationRepositoryError.notFound
        #expect(notFound.errorDescription?.contains("bestaat niet") == true)
    }
}
