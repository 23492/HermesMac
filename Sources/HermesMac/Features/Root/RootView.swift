import SwiftUI
import SwiftData

/// Top-level navigation shell. On macOS this is a `NavigationSplitView`
/// (sidebar + detail); on iOS it is a `NavigationStack` with the
/// conversation list as the root and `ChatView` as the pushed destination.
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

    @State private var selectedConversationID: UUID?

    #if os(iOS)
    /// Programmatic navigation path for iOS. Mutated by
    /// ``createNewChat()`` to push a freshly created conversation on
    /// top of the stack.
    @State private var navigationPath: [UUID] = []
    #endif

    public init() {}

    public var body: some View {
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
                selectedID: $selectedConversationID,
                onNewChat: createNewChat,
                onDelete: deleteConversation
            )
        } detail: {
            if let id = selectedConversationID,
               let conversation = conversations.first(where: { $0.id == id }) {
                ChatView(conversation: conversation)
            } else {
                emptyState
            }
        }
        .focusedSceneValue(\.newChatAction, createNewChat)
    }
    #endif

    // MARK: - iOS body

    #if os(iOS)
    private var iosBody: some View {
        NavigationStack(path: $navigationPath) {
            ConversationListView(
                conversations: conversations,
                selectedID: $selectedConversationID,
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

    @ViewBuilder
    private var emptyState: some View {
        if !settings.hasValidConfiguration {
            needsConfigurationState
        } else {
            pickOrCreateState
        }
    }

    private var pickOrCreateState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Selecteer een chat of maak een nieuwe aan")
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

            Text("Geen API key ingesteld")
                .font(.headline)

            Text("Voeg je Hermes API key toe om te beginnen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            #if os(macOS)
            Button {
                openSettings()
            } label: {
                Label("Open Instellingen", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
        .padding(32)
        .frame(maxWidth: 360)
    }

    // MARK: - Actions

    private func createNewChat() {
        let repo = ConversationRepository(context: modelContext)
        do {
            let conversation = try repo.create(model: settings.selectedModel)
            #if os(iOS)
            navigationPath = [conversation.id]
            #else
            selectedConversationID = conversation.id
            #endif
        } catch {
            // Conversation creation failed — unlikely but not fatal
        }
    }

    private func deleteConversation(_ conversation: ConversationEntity) {
        let repo = ConversationRepository(context: modelContext)
        do {
            try repo.delete(conversation)
        } catch {
            // Deletion failed — unlikely but not fatal
        }
    }
}
