# Task 08: ChatModel + streaming integratie

**Status:** Niet gestart
**Dependencies:** Task 03, Task 04, Task 05, Task 07
**Estimated effort:** 40 min

## Doel

Implementeer `ChatModel`, de state-houder voor één chat view. Houdt messages bij, streamt het assistent antwoord via `HermesClient`, slaat op via `ConversationRepository`.

## Context

Dit is waar al het voorgaande werk samenkomt. `ChatView` uit task 09 wordt een dunne render-laag bovenop deze ChatModel.

Belangrijke design beslissingen:
- `ChatModel` is `@Observable` en `@MainActor`
- Hij bezit één `Task` voor de actieve streaming — bij nieuwe send eerst oude cancelen
- Streaming chunks worden rechtstreeks op het laatste `MessageEntity.content` aangehangen (model mutations op main actor zijn safe voor SwiftData)
- Bij cancel wordt het partial bericht bewaard, niet weggegooid

## Scope

### In scope
- `Sources/HermesMac/Features/Chat/ChatModel.swift`
- State: `messages`, `isStreaming`, `errorMessage`, `inputText`
- Methods: `send()`, `cancel()`, `retry()` (later), `deleteMessage(_:)`
- `Tests/HermesMacTests/ChatModelTests.swift` — test state transitions, niet de actual netwerk call

### Niet in scope
- Regenerate last response (task 12)
- Edit user message (task 12)
- Tool call rendering (niet in v1)

## Implementation

```swift
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class ChatModel {

    // MARK: - State

    public var inputText: String = ""
    public var isStreaming: Bool = false
    public var errorMessage: String?

    public private(set) var conversation: ConversationEntity
    public private(set) var messages: [MessageEntity]

    // MARK: - Dependencies

    private let client: HermesClient
    private let selector: EndpointSelector
    private let settings: AppSettings
    private let repository: ConversationRepository

    private var streamingTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        conversation: ConversationEntity,
        client: HermesClient,
        selector: EndpointSelector,
        settings: AppSettings,
        repository: ConversationRepository
    ) {
        self.conversation = conversation
        self.messages = conversation.messages.sorted(by: { $0.createdAt < $1.createdAt })
        self.client = client
        self.selector = selector
        self.settings = settings
        self.repository = repository
    }

    // MARK: - Actions

    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        inputText = ""
        errorMessage = nil

        // Cancel any prior streaming task
        streamingTask?.cancel()

        // Save user message
        do {
            let userMessage = try repository.appendMessage(
                role: "user",
                content: text,
                to: conversation
            )
            messages.append(userMessage)

            // Title generation: first user message becomes title
            if conversation.title == "Nieuwe chat" {
                let title = String(text.prefix(40))
                try repository.updateTitle(title, for: conversation)
            }
        } catch {
            errorMessage = "Kan je bericht niet opslaan: \(error.localizedDescription)"
            return
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

        // Build history
        let history = messages
            .filter { $0.id != assistantMessage.id }
            .map { ChatMessage(role: $0.role, content: $0.content) }

        let request = ChatCompletionRequest(
            model: conversation.model,
            messages: history,
            stream: true
        )

        // Start streaming task
        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Pick endpoint
                guard let primary = self.settings.primaryURL else {
                    throw HermesError.invalidURL
                }
                let primaryEndpoint = HermesEndpoint(baseURL: primary, apiKey: self.settings.apiKey)
                let localEndpoint = self.settings.localURL.map {
                    HermesEndpoint(baseURL: $0, apiKey: self.settings.apiKey)
                }
                let selection = try await self.selector.pick(
                    primary: primaryEndpoint,
                    local: localEndpoint
                )
                await self.client.setEndpoint(selection.endpoint)

                let stream = try await self.client.streamChatCompletion(request: request)

                for try await chunk in stream {
                    if Task.isCancelled { break }
                    assistantMessage.content.append(chunk)
                    // Force SwiftUI to see the change by re-assigning the array element
                    // (needed because @Model classes are reference types)
                    self.notifyContentChanged()
                }

                // Save final state
                try? self.repository.appendMessage(
                    role: "", content: "",
                    to: self.conversation
                ) // no-op bump to force save on updatedAt; alternative: call a dedicated touch method
                // Actually just do:
                try? self.repositorySave()

            } catch is CancellationError {
                // User-initiated cancel, keep partial content
            } catch {
                self.errorMessage = error.localizedDescription
                // Clean up empty placeholder if nothing was received
                if assistantMessage.content.isEmpty {
                    try? self.repository.deleteMessageEntity(assistantMessage)
                    self.messages.removeAll { $0.id == assistantMessage.id }
                }
            }

            self.isStreaming = false
            self.streamingTask = nil
        }
    }

    public func cancel() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
    }

    // MARK: - Private helpers

    private func notifyContentChanged() {
        // SwiftData models are classes — mutating content already triggers @Observable
        // tracking via the Model macro. This function is a no-op marker where we'd
        // add explicit willChange calls if needed.
    }

    private func repositorySave() throws {
        // Stub: repository's appendMessage already saves. For explicit touch, extend
        // ConversationRepository with a `touch(_ conversation:)` method in a followup.
    }
}
```

**Let op:** bovenstaande code heeft wat rommelige placeholder logic rond "repositorySave" en "deleteMessageEntity". Ruim dit op tijdens de implementatie door:

1. `ConversationRepository.delete(message:)` toe te voegen
2. Een `ConversationRepository.touch(_ conversation:)` method toe te voegen die alleen updatedAt en save doet
3. De streaming flow herschrijven met deze helpers

Dit is geen vrijbrief voor scope creep. Alleen deze twee methods extra op de repository.

## Tests

Mock `HermesClient` en `EndpointSelector` via protocol extraction als nodig, of gebruik integration tests met MockURLProtocol.

Minimaal te testen:
- Initial state na init
- `send()` met lege input doet niks
- `send()` voegt user message en assistant placeholder toe
- `cancel()` reset isStreaming

Streaming integratie test mag worden uitgesteld naar een followup.

## Done when

- [ ] ChatModel bestaat en compileert
- [ ] Basis tests passen
- [ ] Repository helpers toegevoegd voor delete+touch
- [ ] Commit: `feat(task08): ChatModel with streaming integration`

## Open punten

Deze task is de meest complexe in v1. Als je vast komt te zitten op de SwiftData+Observable interactie, implementeer een "dumber" variant waar je `messages: [MessageEntity]` manueel wist en herbouwt na elke update. Liever werkend dan elegant.
