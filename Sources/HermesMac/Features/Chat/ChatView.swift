import SwiftUI
import SwiftData

/// Main chat view showing the message list and composer for a single conversation.
public struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    let conversation: ConversationEntity

    @State private var model: ChatModel?

    public init(conversation: ConversationEntity) {
        self.conversation = conversation
    }

    public var body: some View {
        Group {
            if let model {
                chatContent(model: model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(conversation.title)
        .task(id: conversation.id) {
            let repo = ConversationRepository(context: modelContext)
            let client = HermesClient()
            self.model = ChatModel(
                conversation: conversation,
                client: client,
                settings: settings,
                repository: repo
            )
        }
    }

    @ViewBuilder
    private func chatContent(model: ChatModel) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.messages) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy, messages: model.messages)
                }
                .onChange(of: model.messages.last?.content) { _, _ in
                    scrollToBottom(proxy: proxy, messages: model.messages)
                }
            }

            if let error = model.errorMessage {
                errorBanner(error)
            }

            MessageComposerView(
                text: Binding(
                    get: { model.inputText },
                    set: { model.inputText = $0 }
                ),
                isStreaming: model.isStreaming,
                onSend: { model.send() },
                onCancel: { model.cancel() }
            )
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, messages: [MessageEntity]) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.red.opacity(0.9))
    }
}
