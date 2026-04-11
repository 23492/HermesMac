import Foundation
import os
import SwiftData

/// Typed errors thrown by ``ConversationRepository``.
///
/// Every repository method wraps raw SwiftData errors in one of these cases
/// so that upstream code (chat view models, root view) can pattern-match on
/// the failure mode and surface a localised message to the user instead of
/// dealing with `NSError` at the UI layer.
public enum ConversationRepositoryError: Error, LocalizedError, Sendable {

    /// A fetch against the model context failed.
    case fetchFailed(underlying: String)

    /// A save against the model context failed (insert, update or delete).
    case saveFailed(underlying: String)

    /// A lookup expected an entity that did not exist in the store.
    case notFound

    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let detail):
            return "Gesprekken ophalen is mislukt: \(detail)"
        case .saveFailed(let detail):
            return "Opslaan is mislukt: \(detail)"
        case .notFound:
            return "Dit gesprek bestaat niet (meer)."
        }
    }
}

/// Main-actor isolated repository that owns the SwiftData ``ModelContext``
/// for conversations and messages.
///
/// All write operations save immediately so the on-disk store always matches
/// what the UI shows. Errors are surfaced as typed
/// ``ConversationRepositoryError`` values so callers can pattern-match and
/// render localised messages.
///
/// ### Threading
///
/// Marked `@MainActor` because SwiftData entities are not `Sendable` and the
/// project policy (see `docs/ARCHITECTURE.md`) is "SwiftData mutations happen
/// on the main actor in v1". Do not dispatch repository calls onto a
/// background queue.
@MainActor
public final class ConversationRepository {

    /// Subsystem/category used for repository-level logging.
    private static let logger = Logger(
        subsystem: "com.hermes.mac",
        category: "conversation-repository"
    )

    /// The SwiftData model context this repository writes into.
    private let context: ModelContext

    /// Creates a repository bound to the given model context.
    ///
    /// - Parameter context: The SwiftData context to read from and write
    ///   into. Typically the environment context injected by the
    ///   `.modelContainer(...)` modifier at the root of the app.
    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Read

    /// Returns all conversations sorted by ``ConversationEntity/updatedAt``
    /// descending (most recently touched first).
    ///
    /// Sidebars and list views should prefer this over a hand-rolled
    /// `FetchDescriptor` so they always agree on the sort order.
    ///
    /// - Returns: Conversations sorted newest-touched first.
    /// - Throws: ``ConversationRepositoryError/fetchFailed(underlying:)``
    ///   when the underlying SwiftData fetch fails.
    public func listAll() throws -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.id)
            ]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ConversationRepositoryError.fetchFailed(
                underlying: error.localizedDescription
            )
        }
    }

    // MARK: - Create

    /// Creates and persists a new empty conversation for the given model.
    ///
    /// The default title is resolved through `String(localized:)` so that
    /// the entity itself stays locale-agnostic and all user-visible strings
    /// live in a single place (the repository).
    ///
    /// - Parameter model: The model identifier to bind the conversation to
    ///   (e.g. `"hermes-agent"`).
    /// - Returns: The freshly inserted conversation.
    /// - Throws: ``ConversationRepositoryError/saveFailed(underlying:)``
    ///   when the save fails.
    @discardableResult
    public func create(model: String) throws -> ConversationEntity {
        let conversation = ConversationEntity(
            title: Self.defaultConversationTitle,
            model: model
        )
        context.insert(conversation)
        try save()
        return conversation
    }

    // MARK: - Delete

    /// Deletes a conversation and cascades to all of its messages.
    ///
    /// - Parameter conversation: The conversation to remove.
    /// - Throws: ``ConversationRepositoryError/saveFailed(underlying:)``
    ///   when the save fails.
    public func delete(_ conversation: ConversationEntity) throws {
        context.delete(conversation)
        try save()
    }

    /// Deletes a single message.
    ///
    /// The inverse relationship on ``ConversationEntity/messages`` handles
    /// the parent array update automatically — do not manually remove the
    /// message from `conversation.messages`. We still bump the parent's
    /// ``ConversationEntity/updatedAt`` so the sidebar re-sorts.
    ///
    /// - Parameter message: The message to remove.
    /// - Throws: ``ConversationRepositoryError/saveFailed(underlying:)``
    ///   when the save fails.
    public func delete(message: MessageEntity) throws {
        message.conversation?.updatedAt = Date()
        context.delete(message)
        try save()
    }

    // MARK: - Update

    /// Updates the title of a conversation and touches its ``updatedAt``.
    ///
    /// - Parameters:
    ///   - title: New user-visible title.
    ///   - conversation: The conversation to rename.
    /// - Throws: ``ConversationRepositoryError/saveFailed(underlying:)``
    ///   when the save fails.
    public func updateTitle(
        _ title: String,
        for conversation: ConversationEntity
    ) throws {
        conversation.title = title
        conversation.updatedAt = Date()
        try save()
    }

    /// Touches a conversation's ``updatedAt`` and saves.
    ///
    /// Useful after a streaming reply finishes when no other field changed
    /// but we still want the conversation to bubble to the top of the
    /// sidebar.
    ///
    /// - Parameter conversation: The conversation to touch.
    /// - Throws: ``ConversationRepositoryError/saveFailed(underlying:)``
    ///   when the save fails.
    public func touch(_ conversation: ConversationEntity) throws {
        conversation.updatedAt = Date()
        try save()
    }

    // MARK: - Append

    /// Appends a message to a conversation.
    ///
    /// Only sets ``MessageEntity/conversation`` — SwiftData's inverse
    /// relationship populates ``ConversationEntity/messages`` automatically
    /// and also inserts the new entity into the context. Appending to the
    /// parent's array or calling `context.insert(message)` in addition will
    /// triple-wire the link and break change tracking in subtle ways.
    ///
    /// The parent's ``ConversationEntity/updatedAt`` is bumped to now so the
    /// sidebar re-sorts.
    ///
    /// - Parameters:
    ///   - role: Raw role string (use a ``MessageRole`` raw value where
    ///     possible, or see the typed overload).
    ///   - content: Message body.
    ///   - conversation: The parent conversation.
    /// - Returns: The newly created message.
    /// - Throws: ``ConversationRepositoryError/saveFailed(underlying:)``
    ///   when the save fails.
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
        conversation.updatedAt = Date()
        try save()
        return message
    }

    /// Typed overload of ``appendMessage(role:content:to:)-(String,_,_)`` that
    /// takes a ``MessageRole`` directly.
    ///
    /// Prefer this at call sites that know the role at compile time — it
    /// removes a class of typo bugs like `"usser"` that the string-based
    /// overload cannot catch.
    ///
    /// - Parameters:
    ///   - role: Typed role.
    ///   - content: Message body.
    ///   - conversation: The parent conversation.
    /// - Returns: The newly created message.
    /// - Throws: ``ConversationRepositoryError/saveFailed(underlying:)``
    ///   when the save fails.
    @discardableResult
    public func appendMessage(
        role: MessageRole,
        content: String,
        to conversation: ConversationEntity
    ) throws -> MessageEntity {
        try appendMessage(
            role: role.rawValue,
            content: content,
            to: conversation
        )
    }

    // MARK: - Pruning

    /// Deletes all conversations with zero messages, excluding the given ID.
    ///
    /// Intended to be called right after creating a new chat so stale empty
    /// conversations don't pile up in the sidebar. The excluded ID is
    /// typically the just-created conversation that should survive.
    ///
    /// Errors are logged but never thrown — pruning is best-effort
    /// housekeeping that must not block the caller or surface an alert.
    ///
    /// - Parameter id: The conversation ID to keep even if it has no messages.
    public func pruneEmpty(excluding id: UUID) {
        do {
            let all = try context.fetch(FetchDescriptor<ConversationEntity>())
            let empties = all.filter { $0.messages.isEmpty && $0.id != id }
            for conversation in empties {
                context.delete(conversation)
            }
            try context.save()
        } catch {
            Self.logger.error(
                "pruneEmpty failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Context save

    /// Saves the underlying SwiftData context.
    ///
    /// Intended for mid-stream saves where the caller wants to flush
    /// accumulated mutations (e.g. partial assistant content) without going
    /// through a full CRUD method. Errors are mapped to
    /// ``ConversationRepositoryError/saveFailed(underlying:)`` like every
    /// other repository write.
    public func saveContext() throws {
        try save()
    }

    // MARK: - Private helpers

    /// Wraps `context.save()` so every repository method maps raw SwiftData
    /// errors to ``ConversationRepositoryError/saveFailed(underlying:)``.
    private func save() throws {
        do {
            try context.save()
        } catch {
            throw ConversationRepositoryError.saveFailed(
                underlying: error.localizedDescription
            )
        }
    }

    /// Localised default title used by ``create(model:)``. Pulled from a
    /// `String(localized:)` lookup so the entity itself stays
    /// locale-agnostic. Dutch default matches the rest of the app copy.
    private static var defaultConversationTitle: String {
        String(
            localized: "chat.default.title",
            defaultValue: "Nieuwe chat",
            comment: "Default title used when a new empty conversation is created."
        )
    }
}
