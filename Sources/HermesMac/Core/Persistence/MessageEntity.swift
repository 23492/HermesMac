import Foundation
import SwiftData

/// Typed set of roles a message can have in a chat conversation.
///
/// Uses `String` as the raw value so SwiftData can store it transparently and
/// so existing call sites can still interop with OpenAI-style role strings on
/// the wire.
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

    /// Raw role string as sent to / received from the backend (OpenAI
    /// chat-completions compatible: `"user"`, `"assistant"`, `"system"`,
    /// `"tool"`).
    ///
    /// This is stored as `String` for forward compatibility with the rest of
    /// the app — which still talks to the chat-completions API in strings —
    /// but typed access is available via ``roleEnum``.
    public var role: String

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

    /// Typed accessor over ``role``. Returns `nil` when the stored string
    /// value is not one of the known ``MessageRole`` cases — callers should
    /// still be defensive because the underlying storage is a plain string.
    public var roleEnum: MessageRole? {
        MessageRole(rawValue: role)
    }

    /// Creates a new message entity with a raw-string role.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a fresh `UUID`.
    ///   - role: Role string (use a ``MessageRole`` raw value where
    ///     possible).
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
        self.role = role
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
