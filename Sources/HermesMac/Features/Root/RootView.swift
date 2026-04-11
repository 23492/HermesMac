import SwiftUI
import SwiftData

/// Top-level navigation shell. On macOS this is a `NavigationSplitView`
/// (sidebar + detail); on iOS it is a `NavigationStack` with the
/// conversation list as the root and `ChatView` as the pushed destination.
///
/// ``RootView`` also owns two app-shell responsibilities:
///
/// - Publishing the "Nieuwe chat" action to ``FocusedValues`` so the
///   Cmd+N menu command works from cold start, before any conversation
///   has been selected.
/// - Surfacing repository errors from ``createNewChat()`` and
///   ``deleteConversation(_:)`` in a SwiftUI `.alert` so the user is
///   never left wondering why a button did nothing.
public struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    #if os(macOS)
    /// Built-in SwiftUI action that opens the dedicated `Settings`
    /// scene on macOS — used by the "Open Instellingen" button in the
    /// empty state when the user has not configured an API key yet.
    @Environment(\.openSettings) private var openSettings
    #endif

    @Query(sort: \ConversationEntity.updatedAt, order: .reverse)
    private var conversations: [ConversationEntity]

    /// Currently selected conversation, held as a direct reference so
    /// the split-view detail pane does not have to scan the
    /// ``conversations`` array on every update. `nil` = nothing
    /// selected (empty state).
    @State private var selectedConversation: ConversationEntity?

    /// Last repository error, if any. Non-nil values drive the
    /// `.alert` modifier on the root body.
    @State private var repositoryError: RepositoryErrorWrapper?

    #if os(iOS)
    /// Programmatic navigation path for iOS. Mutated by
    /// ``createNewChat()`` to push a freshly created conversation on
    /// top of the stack.
    @State private var navigationPath: [UUID] = []
    #endif

    public init() {}

    public var body: some View {
        content
            #if os(macOS)
            .focusedSceneValue(\.newChatAction, createNewChat)
            #endif
            .alert(
                String(localized: "root.alert.actionFailed", defaultValue: "Kan actie niet uitvoeren"),
                isPresented: repositoryErrorBinding,
                presenting: repositoryError
            ) { _ in
                Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {
                    repositoryError = nil
                }
            } message: { wrapper in
                Text(wrapper.message)
            }
    }

    private var content: some View {
        #if os(iOS)
        iosBody
        #else
        macOSBody
        #endif
    }

    // MARK: - macOS body

    #if os(macOS)
    private var macOSBody: some View {
        NavigationSplitView {
            ConversationListView(
                conversations: conversations,
                selection: $selectedConversation,
                onNewChat: createNewChat,
                onDelete: deleteConversation
            )
        } detail: {
            if let conversation = selectedConversation {
                ChatView(conversation: conversation)
            } else {
                emptyState
            }
        }
    }
    #endif

    // MARK: - iOS body

    #if os(iOS)
    private var iosBody: some View {
        NavigationStack(path: $navigationPath) {
            ConversationListView(
                conversations: conversations,
                selection: $selectedConversation,
                onNewChat: createNewChat,
                onDelete: deleteConversation
            )
            .navigationDestination(for: UUID.self) { id in
                if let conversation = conversations.first(where: { $0.id == id }) {
                    ChatView(conversation: conversation)
                }
            }
        }
    }
    #endif

    // MARK: - Empty state

    private var emptyState: some View {
        Group {
            if !settings.hasValidConfiguration {
                needsConfigurationState
            } else {
                pickOrCreateState
            }
        }
    }

    private var pickOrCreateState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(String(localized: "emptyState.selectOrCreate", defaultValue: "Selecteer een chat of maak een nieuwe aan"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    /// Shown in the detail pane when no API key is configured yet.
    /// Offers a direct jump into the Settings scene via the built-in
    /// `openSettings` environment action.
    private var needsConfigurationState: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(String(localized: "emptyState.noApiKey.title", defaultValue: "Geen API key ingesteld"))
                .font(.headline)

            Text(String(localized: "emptyState.noApiKey.body", defaultValue: "Voeg je Hermes API key toe om te beginnen."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            #if os(macOS)
            Button {
                openSettings()
            } label: {
                Label(String(localized: "action.openSettings", defaultValue: "Open Instellingen"), systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
        .padding(32)
        .frame(maxWidth: 360)
    }

    // MARK: - Actions

    /// Creates a new empty conversation and selects it. On iOS the
    /// new conversation is pushed onto the navigation stack; on macOS
    /// it becomes the split-view selection.
    ///
    /// Repository errors are surfaced via ``repositoryError`` so the
    /// `.alert` modifier on the body picks them up.
    private func createNewChat() {
        let repo = ConversationRepository(context: modelContext)
        do {
            let conversation = try repo.create(model: settings.selectedModel)
            repo.pruneEmpty(excluding: conversation.id)
            #if os(iOS)
            navigationPath = [conversation.id]
            selectedConversation = conversation
            #else
            selectedConversation = conversation
            #endif
        } catch {
            repositoryError = RepositoryErrorWrapper(
                message: String(localized: "root.error.createFailed", defaultValue: "Kon geen nieuwe chat maken: \(error.localizedDescription)")
            )
        }
    }

    /// Deletes the given conversation and clears the selection if it
    /// was pointing at the deleted row.
    private func deleteConversation(_ conversation: ConversationEntity) {
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        let repo = ConversationRepository(context: modelContext)
        do {
            try repo.delete(conversation)
        } catch {
            repositoryError = RepositoryErrorWrapper(
                message: String(localized: "root.error.deleteFailed", defaultValue: "Kon chat niet verwijderen: \(error.localizedDescription)")
            )
        }
    }

    // MARK: - Alert plumbing

    /// Two-way binding used by the `.alert` modifier. Set to `false`
    /// by the OK button; reading the wrapped value always reflects
    /// whether ``repositoryError`` is non-nil.
    private var repositoryErrorBinding: Binding<Bool> {
        Binding(
            get: { repositoryError != nil },
            set: { newValue in
                if !newValue { repositoryError = nil }
            }
        )
    }
}

/// Identifiable wrapper around a presentable error message.
///
/// SwiftUI's `.alert(_:isPresented:presenting:)` wants an `Identifiable`
/// item so it can diff; we do not want to make the raw ``Error`` type
/// conform because the concrete error may come from repository, IO, or
/// any third-party layer.
private struct RepositoryErrorWrapper: Identifiable {
    let id = UUID()
    let message: String
}
