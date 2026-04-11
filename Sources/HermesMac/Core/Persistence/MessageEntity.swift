import Foundation
import SwiftData

/// Typed set of roles a message can have in a chat conversation.
///
/// Uses `String` as the raw value so SwiftData can persist it transparently
/// (the raw value is what ends up in the store) and so interop with
/// OpenAI-style role strings on the wire remains trivial via ``rawValue``.
///
/// - `user`: A message the human typed.
/// - `assistant`: A reply produced by the model (including mid-stream
///   chunks concatenated together).
/// - `system`: A system prompt scoped to the conversation.
/// - `tool`: Output produced by a tool execution the agent invoked. The
///   Hermes backend currently in-lines tool output in `assistant` content, so
///   this case is reserved for forward compatibility.
public enum MessageRole: String, Codable, Sendable, CaseIterable {
    case user
    case assistant
    case system
    case tool
}

/// SwiftData entity representing a single message inside a
/// ``ConversationEntity``.
///
/// The inverse relationship lives on ``ConversationEntity/messages``. To
/// attach a message to its parent, set ``conversation`` — do not also append
/// to the parent's messages array, SwiftData will do that for you.
@Model
public final class MessageEntity {

    /// Stable identifier for the message.
    @Attribute(.unique) public var id: UUID

    /// The role of this message in the conversation.
    ///
    /// Stored as a ``MessageRole`` enum. SwiftData persists the raw `String`
    /// value transparently because `MessageRole` is `RawRepresentable` with
    /// a `Codable` raw type.
    public var role: MessageRole

    /// Raw text content of the message. For streamed assistant messages this
    /// grows over time as chunks are appended.
    public var content: String

    /// When the message was created.
    public var createdAt: Date

    /// The conversation this message belongs to.
    ///
    /// This is the authoritative write side of the relationship with
    /// ``ConversationEntity/messages``: setting this property is sufficient
    /// to link the message to its parent. The cascade delete rule ensures
    /// the message goes away when the parent conversation is deleted.
    public var conversation: ConversationEntity?

    /// Creates a new message entity with a raw-string role.
    ///
    /// The string is converted to ``MessageRole`` via its raw value.
    /// Unknown strings fall back to ``MessageRole/user`` for safety.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a fresh `UUID`.
    ///   - role: Role string. Converted to ``MessageRole`` using
    ///     `MessageRole(rawValue:)` with a `.user` fallback.
    ///   - content: Message body. May be empty — e.g. for a placeholder that
    ///     will be filled in by streaming.
    ///   - createdAt: Creation timestamp. Defaults to `Date()`.
    ///   - conversation: Optional parent conversation. Set this to wire the
    ///     relationship; do not also `append` to the parent's messages
    ///     array.
    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        createdAt: Date = Date(),
        conversation: ConversationEntity? = nil
    ) {
        self.id = id
        self.role = MessageRole(rawValue: role) ?? .user
        self.content = content
        self.createdAt = createdAt
        self.conversation = conversation
    }

    /// Creates a new message entity with a typed role.
    ///
    /// Preferred over the raw-string initialiser at call sites that know the
    /// role at compile time.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a fresh `UUID`.
    ///   - role: Typed role value.
    ///   - content: Message body.
    ///   - createdAt: Creation timestamp. Defaults to `Date()`.
    ///   - conversation: Optional parent conversation.
    public convenience init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        conversation: ConversationEntity? = nil
    ) {
        self.init(
            id: id,
            role: role.rawValue,
            content: content,
            createdAt: createdAt,
            conversation: conversation
        )
    }
}
