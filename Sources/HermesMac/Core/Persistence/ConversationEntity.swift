import Foundation
import SwiftData

/// SwiftData entity representing a single conversation with the Hermes agent.
///
/// A conversation owns an ordered collection of ``MessageEntity`` values via a
/// cascading `@Relationship`. The relationship is *unidirectional from the
/// write side*: callers set `message.conversation = conversation` on a new
/// ``MessageEntity`` and SwiftData populates ``messages`` automatically — do
/// not also `append(...)` manually or you will double-wire the link and
/// confuse SwiftData's change tracking.
///
/// The entity itself is intentionally locale-agnostic: no user-facing strings
/// are hard-coded here. The repository layer is responsible for injecting a
/// localised default title when it creates a new conversation.
@Model
public final class ConversationEntity {

    /// Stable identifier for the conversation. Used as the primary key and
    /// survives store-to-store migrations.
    @Attribute(.unique) public var id: UUID

    /// User-visible title of the conversation. Initially an empty string
    /// (locale-agnostic); the repository assigns a localised default on
    /// create and the chat flow may overwrite it with the first user prompt.
    public var title: String

    /// Model identifier this conversation is bound to (e.g. `"hermes-agent"`).
    public var model: String

    /// When the conversation was first created.
    public var createdAt: Date

    /// When the conversation was last touched (new message, title edit,
    /// explicit touch). Used as the sort key in the sidebar.
    public var updatedAt: Date

    /// Messages that belong to this conversation, ordered by their insertion
    /// time (callers typically sort by ``MessageEntity/createdAt`` for
    /// display).
    ///
    /// The inverse side lives on ``MessageEntity/conversation``. The cascade
    /// delete rule ensures messages are removed together with their parent
    /// conversation; call sites must not attempt to remove messages from
    /// this array manually.
    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.conversation)
    public var messages: [MessageEntity]

    /// Creates a new conversation.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a fresh `UUID`.
    ///   - title: User-visible title. Defaults to an empty string so the
    ///     entity stays locale-agnostic; the repository supplies a localised
    ///     default string when creating conversations.
    ///   - model: Model identifier (e.g. `"hermes-agent"`).
    ///   - createdAt: Creation timestamp. Also used as the initial
    ///     `updatedAt`. Defaults to `Date()`.
    public init(
        id: UUID = UUID(),
        title: String = "",
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
