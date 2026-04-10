import Testing
import SwiftData
@testable import HermesMac

@Suite("ChatModel")
@MainActor
struct ChatModelTests {

    // MARK: - Helpers

    private func makeDependencies() throws -> (
        ConversationEntity,
        HermesClient,
        AppSettings,
        ConversationRepository
    ) {
        let container = try ModelStack.makeInMemoryContainer()
        let ctx = ModelContext(container)
        let repo = ConversationRepository(context: ctx)
        let conv = try repo.create(model: "hermes-agent")
        let client = HermesClient()
        let settings = AppSettings.shared
        return (conv, client, settings, repo)
    }

    private func makeModel() throws -> ChatModel {
        let (conv, client, settings, repo) = try makeDependencies()
        return ChatModel(
            conversation: conv,
            client: client,
            settings: settings,
            repository: repo
        )
    }

    // MARK: - Tests

    @Test("initial state after init")
    func initialState() throws {
        let model = try makeModel()

        #expect(model.inputText == "")
        #expect(model.isStreaming == false)
        #expect(model.errorMessage == nil)
        #expect(model.messages.isEmpty)
        #expect(model.conversation.title == "Nieuwe chat")
    }

    @Test("send with empty input does nothing")
    func sendEmptyInput() throws {
        let model = try makeModel()
        model.inputText = ""

        model.send()

        #expect(model.messages.isEmpty)
        #expect(model.isStreaming == false)
        #expect(model.errorMessage == nil)
    }

    @Test("send with whitespace-only input does nothing")
    func sendWhitespaceInput() throws {
        let model = try makeModel()
        model.inputText = "   \n  "

        model.send()

        #expect(model.messages.isEmpty)
        #expect(model.isStreaming == false)
    }

    @Test("send appends user message and assistant placeholder")
    func sendAppendsMessages() throws {
        let model = try makeModel()
        model.inputText = "Hallo wereld"

        model.send()

        #expect(model.messages.count == 2)
        #expect(model.messages[0].role == "user")
        #expect(model.messages[0].content == "Hallo wereld")
        #expect(model.messages[1].role == "assistant")
        #expect(model.messages[1].content == "")
        #expect(model.inputText == "")
    }

    @Test("send sets isStreaming to true")
    func sendSetsStreaming() throws {
        let model = try makeModel()
        model.inputText = "test"

        model.send()

        #expect(model.isStreaming == true)
    }

    @Test("send auto-titles conversation from first user message")
    func sendAutoTitles() throws {
        let model = try makeModel()
        model.inputText = "Dit is mijn eerste bericht aan de agent"

        model.send()

        #expect(model.conversation.title == "Dit is mijn eerste bericht aan de agent")
    }

    @Test("send truncates long title to 40 characters")
    func sendTruncatesLongTitle() throws {
        let model = try makeModel()
        let longText = String(repeating: "x", count: 80)
        model.inputText = longText

        model.send()

        #expect(model.conversation.title.count == 40)
    }

    @Test("cancel resets isStreaming")
    func cancelResetsStreaming() throws {
        let model = try makeModel()
        model.inputText = "test"

        model.send()
        #expect(model.isStreaming == true)

        model.cancel()
        #expect(model.isStreaming == false)
    }

    @Test("send while already streaming does nothing")
    func sendWhileStreamingIgnored() throws {
        let model = try makeModel()
        model.inputText = "first"

        model.send()
        #expect(model.messages.count == 2)

        model.inputText = "second"
        model.send()

        // Should still have only the first pair
        #expect(model.messages.count == 2)
    }

    @Test("deleteMessage removes message from list")
    func deleteMessage() throws {
        let (conv, client, settings, repo) = try makeDependencies()
        let msg = try repo.appendMessage(role: "user", content: "to delete", to: conv)
        let model = ChatModel(
            conversation: conv,
            client: client,
            settings: settings,
            repository: repo
        )

        #expect(model.messages.count == 1)

        model.deleteMessage(msg)

        #expect(model.messages.isEmpty)
    }

    @Test("regenerate does nothing without assistant message")
    func regenerateNoAssistant() throws {
        let (conv, client, settings, repo) = try makeDependencies()
        _ = try repo.appendMessage(role: "user", content: "hi", to: conv)
        let model = ChatModel(
            conversation: conv,
            client: client,
            settings: settings,
            repository: repo
        )

        #expect(model.messages.count == 1)

        model.regenerate()

        #expect(model.messages.count == 1)
        #expect(model.isStreaming == false)
    }

    @Test("regenerate replaces last assistant message and restarts streaming")
    func regenerateReplacesTail() throws {
        let (conv, client, settings, repo) = try makeDependencies()
        _ = try repo.appendMessage(role: "user", content: "hi", to: conv)
        let oldAssistant = try repo.appendMessage(
            role: "assistant",
            content: "old reply",
            to: conv
        )
        let model = ChatModel(
            conversation: conv,
            client: client,
            settings: settings,
            repository: repo
        )

        #expect(model.messages.count == 2)
        #expect(model.messages.last?.id == oldAssistant.id)

        model.regenerate()

        // Old assistant is gone, new empty placeholder is appended
        #expect(model.messages.count == 2)
        #expect(model.messages.last?.id != oldAssistant.id)
        #expect(model.messages.last?.role == "assistant")
        #expect(model.messages.last?.content == "")
        #expect(model.isStreaming == true)
    }

    @Test("regenerate while streaming is ignored")
    func regenerateWhileStreamingIgnored() throws {
        let model = try makeModel()
        model.inputText = "first"
        model.send()

        let beforeCount = model.messages.count
        model.regenerate()

        #expect(model.messages.count == beforeCount)
    }
}
