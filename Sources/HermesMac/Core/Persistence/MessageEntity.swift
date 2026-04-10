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
