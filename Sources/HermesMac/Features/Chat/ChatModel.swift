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

    /// A user-visible error message, set when something goes wrong.
    public var errorMessage: String?

    /// The conversation this model manages.
    public private(set) var conversation: ConversationEntity

    /// Sorted messages for display. Kept in sync with the conversation entity.
    public private(set) var messages: [MessageEntity]

    // MARK: - Dependencies

    private let client: HermesClient
    private let settings: AppSettings
    private let repository: ConversationRepository

    /// The active streaming task, if any.
    private var streamingTask: Task<Void, Never>?

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
        errorMessage = nil

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
            errorMessage = "Kan je bericht niet opslaan: \(error.localizedDescription)"
            return
        }

        // Auto-title: first user message becomes the conversation title
        if conversation.title == "Nieuwe chat" {
            let title = String(text.prefix(40))
            try? repository.updateTitle(title, for: conversation)
        }

        // Create placeholder assistant message
        let assistantMessage: MessageEntity
        do {
            assistantMessage = try repository.appendMessage(
                role: "assistant",
                content: "",
                to: conversation
            )
            messages.append(assistantMessage)
        } catch {
            errorMessage = "Kan antwoord niet voorbereiden: \(error.localizedDescription)"
            return
        }

        isStreaming = true

        // Build message history (exclude the empty assistant placeholder)
        let history = messages
            .filter { $0.id != assistantMessage.id }
            .map { ChatMessage(role: $0.role, content: $0.content) }

        let request = ChatCompletionRequest(
            model: conversation.model,
            messages: history,
            stream: true
        )

        // Start streaming
        streamingTask = Task {
            await performStreaming(request: request, into: assistantMessage)
        }
    }

    /// Cancels the active streaming task, keeping any partial content.
    public func cancel() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
    }

    /// Deletes a message from the conversation.
    public func deleteMessage(_ message: MessageEntity) {
        do {
            try repository.delete(message: message)
            messages.removeAll { $0.id == message.id }
        } catch {
            errorMessage = "Kan bericht niet verwijderen: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    /// Performs the actual streaming loop, appending chunks to the assistant message.
    private func performStreaming(
        request: ChatCompletionRequest,
        into assistantMessage: MessageEntity
    ) async {
        do {
            let endpoint = HermesEndpoint(
                baseURL: settings.backendURL,
                apiKey: settings.apiKey
            )
            await client.setEndpoint(endpoint)

            let stream = try await client.streamChatCompletion(request: request)

            for try await chunk in stream {
                if Task.isCancelled { break }
                assistantMessage.content += chunk
            }

            try? repository.touch(conversation)

        } catch is CancellationError {
            // User-initiated cancel — keep partial content
        } catch {
            errorMessage = error.localizedDescription
            // Remove empty placeholder if nothing was streamed
            if assistantMessage.content.isEmpty {
                try? repository.delete(message: assistantMessage)
                messages.removeAll { $0.id == assistantMessage.id }
            }
        }

        isStreaming = false
        streamingTask = nil
    }
}
