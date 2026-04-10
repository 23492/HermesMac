import SwiftUI
import SwiftData

/// Top-level navigation shell. Uses `NavigationSplitView` which adapts
/// to sidebar+detail on macOS/iPad and a stack on iPhone.
public struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: \ConversationEntity.updatedAt, order: .reverse)
    private var conversations: [ConversationEntity]

    @State private var selectedConversationID: UUID?

    public init() {}

    public var body: some View {
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
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Selecteer een chat of maak een nieuwe aan")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func createNewChat() {
        let repo = ConversationRepository(context: modelContext)
        do {
            let conversation = try repo.create(model: settings.selectedModel)
            selectedConversationID = conversation.id
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
