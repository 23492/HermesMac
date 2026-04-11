import Foundation
import Observation
import SwiftData

/// State holder for a single chat conversation view.
///
/// Manages the message list, streams assistant responses via ``HermesClient``,
/// and persists everything through ``ConversationRepository``.
@Observable
@MainActor
public final class ChatModel {

    // MARK: - State

    /// The text currently in the composer input field.
    public var inputText: String = ""

    /// Whether an assistant response is currently being streamed.
    public private(set) var isStreaming: Bool = false

    /// Typed error state. Set when a send / regenerate / retry fails,
    /// cleared the next time the user successfully starts a new request.
    /// The view layer renders a matching banner or empty state based
    /// on the specific case — see ``ChatError``.
    ///
    /// Write access is restricted to the model so error state can only
    /// be *cleared* from the view layer via ``dismissError()``. This
    /// keeps the error lifecycle in one place and prevents views from
    /// masking real failures by blanking `chatError` with a direct write.
    public private(set) var chatError: ChatError?

    /// Becomes `true` when streaming has been active for more than
    /// ``slowReplyThreshold`` seconds without receiving the first
    /// content chunk. The view uses this to surface a "Nog bezig..."
    /// hint so the user knows the request is alive. Automatically
    /// cleared on first chunk, cancel, or stream completion.
    public private(set) var slowReply: Bool = false

    /// How long to wait for the first content chunk before flipping
    /// ``slowReply`` to `true`. Matches the 15 s threshold from the
    /// task 17 spec.
    public static let slowReplyThreshold: TimeInterval = 15

    /// The conversation this model manages.
    public private(set) var conversation: ConversationEntity

    /// Sorted messages for display. Kept in sync with the conversation
    /// entity via ``syncMessages()`` — callers must use the provided
    /// helpers (``send()``, ``regenerate()``, ``deleteMessage(_:)``) to
    /// mutate state; direct writes from outside the model are not
    /// supported and would not participate in observation.
    public private(set) var messages: [MessageEntity]

    // MARK: - Dependencies

    private let client: HermesClient
    private let settings: AppSettings
    private let repository: ConversationRepository

    /// The active streaming task, if any.
    private var streamingTask: Task<Void, Never>?

    /// The active "slow reply" timer. Scheduled at the start of every
    /// stream, cancelled on first chunk or stream completion.
    private var slowReplyTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a new ChatModel for the given conversation.
    ///
    /// - Parameters:
    ///   - conversation: The conversation entity to manage.
    ///   - client: The Hermes networking client.
    ///   - settings: App settings (provides API key and backend URL).
    ///   - repository: The persistence repository for conversations and messages.
    public init(
        conversation: ConversationEntity,
        client: HermesClient,
        settings: AppSettings,
        repository: ConversationRepository
    ) {
        self.conversation = conversation
        self.messages = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        self.client = client
        self.settings = settings
        self.repository = repository
    }

    // MARK: - Actions

    /// Sends the current input text as a user message and starts streaming the assistant response.
    ///
    /// Does nothing if `inputText` is empty or a stream is already active.
    public func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        inputText = ""
        chatError = nil

        // Cancel any prior streaming task
        streamingTask?.cancel()

        // Save user message
        let userMessage: MessageEntity
        do {
            userMessage = try repository.appendMessage(
                role: "user",
                content: text,
                to: conversation
            )
            messages.append(userMessage)
        } catch {
            chatError = .other("Kan je bericht niet opslaan: \(error.localizedDescription)")
            return
        }

        // Auto-title: first user message becomes the conversation title
        if conversation.title == "Nieuwe chat" {
            let title = String(text.prefix(40))
            try? repository.updateTitle(title, for: conversation)
        }

        startStreaming()
    }

    /// Regenerates the assistant's last response.
    ///
    /// Deletes the most recent assistant message and re-runs streaming with
    /// the remaining history. Does nothing if the last message is not an
    /// assistant reply, if there is no preceding user message, or if a
    /// stream is already active.
    public func regenerate() {
        guard !isStreaming else { return }
        guard let lastAssistant = messages.last, lastAssistant.role == "assistant" else {
            return
        }
        guard messages.count >= 2, messages[messages.count - 2].role == "user" else {
            return
        }

        chatError = nil
        streamingTask?.cancel()

        // Remove the previous assistant answer before requesting a new one
        do {
            try repository.delete(message: lastAssistant)
            messages.removeAll { $0.id == lastAssistant.id }
        } catch {
            chatError = .other("Kan vorig antwoord niet verwijderen: \(error.localizedDescription)")
            return
        }

        startStreaming()
    }

    /// Re-runs the last request after a network / stream error.
    ///
    /// Unlike ``regenerate()`` which requires the user to explicitly ask
    /// for a new answer, ``retry()`` is meant to be invoked from the
    /// error banner when ``chatError`` is set and the user wants to try
    /// the same request again. Any trailing assistant message (empty
    /// placeholder from a failed attempt, or a partially streamed reply
    /// from an interrupted stream) is discarded before re-streaming, so
    /// the request state matches what it looked like just before the
    /// failure.
    public func retry() {
        guard !isStreaming else { return }
        guard chatError != nil else { return }

        // Drop any trailing assistant message — could be an empty
        // placeholder the failure path already removed, or a partial
        // reply from a .streamInterrupted case.
        if let last = messages.last, last.role == "assistant" {
            do {
                try repository.delete(message: last)
                messages.removeAll { $0.id == last.id }
            } catch {
                chatError = .other(
                    "Kan oud antwoord niet opruimen: \(error.localizedDescription)"
                )
                return
            }
        }

        // We need a user message to regenerate from
        guard messages.last?.role == "user" else {
            chatError = .other("Geen bericht om opnieuw te proberen.")
            return
        }

        chatError = nil
        startStreaming()
    }

    /// Cancels the active streaming task, keeping any partial content.
    public func cancel() {
        streamingTask?.cancel()
        streamingTask = nil
        slowReplyTask?.cancel()
        slowReplyTask = nil
        isStreaming = false
        slowReply = false
    }

    /// Deletes a message from the conversation.
    public func deleteMessage(_ message: MessageEntity) {
        do {
            try repository.delete(message: message)
            messages.removeAll { $0.id == message.id }
        } catch {
            chatError = .other("Kan bericht niet verwijderen: \(error.localizedDescription)")
        }
    }

    /// Clears the current ``chatError`` from the view layer.
    ///
    /// Views can call this from a banner dismiss button. Setting
    /// `chatError` directly from outside the model is intentionally
    /// not possible — all error state transitions go through here or
    /// through the request methods.
    public func dismissError() {
        chatError = nil
    }

    // MARK: - Test helpers

    /// Internal hook that lets tests seed an error state without
    /// exercising the full network path. Not part of the public API
    /// surface — production code sets `chatError` through the request
    /// methods, and the view clears it through ``dismissError()``.
    internal func setChatErrorForTesting(_ error: ChatError?) {
        chatError = error
    }

    // MARK: - Private

    /// Re-reads the conversation's persisted messages into the
    /// published ``messages`` array, notifying observers.
    ///
    /// This is the only mechanism that reliably triggers SwiftUI view
    /// updates during streaming: mutating `assistantMessage.content`
    /// on a SwiftData entity is invisible to `@Observable` because the
    /// entity is a reference type and the array's identity hasn't
    /// changed. Re-assigning the whole array forces observation to
    /// notice.
    private func syncMessages() {
        messages = conversation.messages.sorted { $0.createdAt < $1.createdAt }
    }

    /// Shared core used by ``send()``, ``regenerate()`` and ``retry()``:
    /// creates an empty assistant placeholder, snapshots the current
    /// message history and starts a streaming task that writes chunks
    /// into the placeholder. Also schedules the ``slowReply`` timer.
    private func startStreaming() {
        let assistantMessage: MessageEntity
        do {
            assistantMessage = try repository.appendMessage(
                role: "assistant",
                content: "",
                to: conversation
            )
            messages.append(assistantMessage)
        } catch {
            chatError = .other(
                "Kan antwoord niet voorbereiden: \(error.localizedDescription)"
            )
            return
        }

        isStreaming = true
        slowReply = false

        // Schedule the "Nog bezig..." indicator. The Task runs on the
        // same main actor as its containing class so `self.slowReply`
        // writes are safe. Cancelled in three places: on first chunk,
        // on cancel(), and at the tail of performStreaming().
        //
        // `[weak self]` avoids a strong reference cycle: the task
        // outlives the caller by up to `slowReplyThreshold` seconds,
        // and if the view / model is torn down in between we don't
        // want to keep the model alive just to flip a bool.
        slowReplyTask?.cancel()
        slowReplyTask = Task { [weak self, threshold = ChatModel.slowReplyThreshold] in
            try? await Task.sleep(for: .seconds(threshold))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.isStreaming {
                self.slowReply = true
            }
        }

        // Build message history (exclude the empty assistant placeholder)
        let history = messages
            .filter { $0.id != assistantMessage.id }
            .map { ChatMessage(role: $0.role, content: $0.content) }

        let request = ChatCompletionRequest(
            model: conversation.model,
            messages: history,
            stream: true
        )

        // `[weak self]` matches the slow-reply task: a long-running
        // SSE stream should not pin the model alive after the view
        // disappears. If `self` is gone by the time the first chunk
        // arrives we simply exit.
        streamingTask = Task { [weak self] in
            guard let self else { return }
            await self.performStreaming(request: request, into: assistantMessage)
        }
    }

    /// Performs the actual streaming loop, appending chunks to the assistant message.
    private func performStreaming(
        request: ChatCompletionRequest,
        into assistantMessage: MessageEntity
    ) async {
        var receivedAnyChunk = false

        do {
            let endpoint = HermesEndpoint(
                baseURL: settings.backendURL,
                apiKey: settings.apiKey
            )
            await client.setEndpoint(endpoint)

            let stream = try await client.streamChatCompletion(request: request)

            for try await chunk in stream {
                if Task.isCancelled { break }
                if !receivedAnyChunk {
                    receivedAnyChunk = true
                    // First content chunk arrived — tear down the slow
                    // reply indicator so the hint disappears.
                    slowReplyTask?.cancel()
                    slowReplyTask = nil
                    slowReply = false
                }
                assistantMessage.content += chunk
                // Re-publish the array so `@Observable` notices the
                // in-place mutation on the SwiftData reference type.
                syncMessages()
            }

            try? repository.touch(conversation)

        } catch is CancellationError {
            // User-initiated cancel — keep partial content
        } catch {
            chatError = categorise(error, receivedAnyChunk: receivedAnyChunk)
            // Remove empty placeholder if nothing was streamed
            if assistantMessage.content.isEmpty {
                try? repository.delete(message: assistantMessage)
                messages.removeAll { $0.id == assistantMessage.id }
            }
        }

        slowReplyTask?.cancel()
        slowReplyTask = nil
        slowReply = false
        isStreaming = false
        streamingTask = nil
    }

    /// Maps a wire-level error into a ``ChatError`` with the appropriate
    /// UX semantics.
    ///
    /// `receivedAnyChunk` distinguishes a transport failure that happens
    /// before the stream started (`.network`) from one that happens
    /// mid-reply (`.streamInterrupted`), so the view can keep partial
    /// content and offer a retry.
    private func categorise(_ error: Error, receivedAnyChunk: Bool) -> ChatError {
        if let hermes = error as? HermesError {
            switch hermes {
            case .notAuthenticated:
                return .notConfigured
            case .httpStatus(code: 401, _):
                return .authentication
            case .httpStatus(let code, let body):
                let detail = body?.prefix(120).description ?? "HTTP \(code)"
                return .other("HTTP \(code): \(detail)")
            case .transport(let detail):
                return receivedAnyChunk ? .streamInterrupted : .network(detail)
            case .streamEndedUnexpectedly:
                return .streamInterrupted
            case .decoding(let detail):
                return .other("Antwoord niet te lezen: \(detail)")
            case .invalidURL:
                return .other("Backend URL is ongeldig.")
            case .inStream(let message):
                // Task 19: structured in-stream backend error. Treat as a
                // stream interruption if we already have partial content
                // (so the retry UX kicks in), otherwise surface the message.
                return receivedAnyChunk ? .streamInterrupted : .other(message)
            }
        }
        return .other(error.localizedDescription)
    }
}
