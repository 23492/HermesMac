import SwiftUI
import SwiftData

/// Main chat view showing the message list and composer for a single conversation.
public struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    #if os(macOS)
    /// SwiftUI built-in action that opens the `Settings` scene
    /// (`HermesMacApp.body`) when invoked from menu bar or a button.
    @Environment(\.openSettings) private var openSettings
    #endif

    let conversation: ConversationEntity

    @State private var model: ChatModel?

    /// Keyboard focus state for the composer text field. Exposed to
    /// ``HermesMacCommands`` via `.focusedSceneValue(\.focusComposerAction)`
    /// so Cmd+K can pull focus back into the composer.
    @FocusState private var composerFocused: Bool

    #if os(iOS)
    /// Drives the iOS settings sheet triggered from an error banner's
    /// "Open Instellingen" button. On macOS the button calls
    /// `openSettings` directly instead.
    @State private var showSettings = false
    #endif

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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.messages) { msg in
                        MessageBubbleView(
                            message: msg,
                            onCopy: { Clipboard.copy(msg.content) },
                            onDelete: { model.deleteMessage(msg) },
                            onRegenerate: canRegenerate(msg, in: model)
                                ? { model.regenerate() }
                                : nil
                        )
                        .id(msg.id)
                    }
                }
                .padding()
            }
            .overlay(alignment: .center) {
                if model.messages.isEmpty, !settings.hasValidConfiguration {
                    noApiKeyEmptyState
                }
            }
            .onChange(of: model.messages.count) { _, _ in
                scrollToBottom(proxy: proxy, messages: model.messages)
            }
            .onChange(of: model.messages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy, messages: model.messages)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let error = model.chatError {
                    errorBanner(error, model: model)
                } else if model.slowReply {
                    slowReplyBanner
                }

                MessageComposerView(
                    text: Binding(
                        get: { model.inputText },
                        set: { model.inputText = $0 }
                    ),
                    isStreaming: model.isStreaming,
                    focus: $composerFocused,
                    onSend: {
                        HapticFeedback.impact()
                        model.send()
                    },
                    onCancel: { model.cancel() }
                )
            }
            .background(.bar)
        }
        .onChange(of: model.isStreaming) { wasStreaming, isStreaming in
            // Fire a success haptic on the streaming-finished transition,
            // but only when the reply actually landed content (avoids a
            // buzz when the user cancels an empty stream).
            if wasStreaming && !isStreaming && !(model.messages.last?.content.isEmpty ?? true) {
                HapticFeedback.success()
            }
        }
        .focusedSceneValue(\.cancelStreamingAction) {
            model.cancel()
        }
        .focusedSceneValue(\.focusComposerAction) {
            composerFocused = true
        }
        #if os(iOS)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Klaar") { showSettings = false }
                        }
                    }
            }
        }
        #endif
    }

    /// Regenerate is only offered on the last assistant message, since
    /// ``ChatModel/regenerate()`` always replaces the tail of the
    /// conversation. Hiding the menu item elsewhere keeps the UI honest.
    private func canRegenerate(_ message: MessageEntity, in model: ChatModel) -> Bool {
        guard message.role == "assistant" else { return false }
        return model.messages.last?.id == message.id
    }

    private func scrollToBottom(proxy: ScrollViewProxy, messages: [MessageEntity]) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Error banner

    /// Rich error banner keyed off the specific ``ChatError`` case.
    /// Settings-related errors get an "Open Instellingen" button,
    /// transport errors get an "Opnieuw proberen" button.
    @ViewBuilder
    private func errorBanner(_ error: ChatError, model: ChatModel) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName(for: error))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text(error.message)
                    .font(.callout)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    if error.isRetryable {
                        Button("Opnieuw proberen") {
                            model.retry()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.red)
                        .controlSize(.small)
                    }
                    if error.needsSettings {
                        Button("Open Instellingen") {
                            presentSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.red)
                        .controlSize(.small)
                    }
                    Button("Sluiten") {
                        model.chatError = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .foregroundStyle(.white)
                    .controlSize(.small)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.9))
    }

    /// Muted "nog bezig..." hint shown when streaming takes longer than
    /// ``ChatModel/slowReplyThreshold`` seconds without any content.
    private var slowReplyBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Nog bezig met antwoorden...")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    /// Empty-state rendered inside the chat scroll view when the user
    /// has no API key yet and no messages exist. Gives them a direct
    /// path into the settings pane.
    private var noApiKeyEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Geen API key ingesteld")
                .font(.headline)

            Text("Voeg je Hermes API key toe om te beginnen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                presentSettings()
            } label: {
                Label("Open Instellingen", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: 320)
    }

    private func iconName(for error: ChatError) -> String {
        switch error {
        case .notConfigured, .authentication:
            "key.slash"
        case .network:
            "wifi.exclamationmark"
        case .streamInterrupted:
            "bolt.horizontal.circle"
        case .other:
            "exclamationmark.triangle"
        }
    }

    /// Opens the settings UI in a platform-appropriate way.
    ///
    /// - macOS: triggers the built-in `openSettings` environment action,
    ///   which surfaces the dedicated `Settings` scene defined in
    ///   `HermesMacApp`.
    /// - iOS: flips `showSettings` so the local `.sheet` modifier
    ///   attached to `chatContent(model:)` presents `SettingsView`.
    private func presentSettings() {
        #if os(macOS)
        openSettings()
        #else
        showSettings = true
        #endif
    }
}
