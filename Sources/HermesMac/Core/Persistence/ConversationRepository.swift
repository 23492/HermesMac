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
        let descriptor = FetchDescriptor<ConversationEntity>(
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
    @discardableResult
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
