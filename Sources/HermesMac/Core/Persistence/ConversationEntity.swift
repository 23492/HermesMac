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
