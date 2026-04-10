import SwiftUI

/// Sidebar view showing a list of conversations with a "New Chat" button.
public struct ConversationListView: View {
    let conversations: [ConversationEntity]
    @Binding var selectedID: UUID?
    var onNewChat: () -> Void
    var onDelete: (ConversationEntity) -> Void

    public init(
        conversations: [ConversationEntity],
        selectedID: Binding<UUID?>,
        onNewChat: @escaping () -> Void,
        onDelete: @escaping (ConversationEntity) -> Void
    ) {
        self.conversations = conversations
        self._selectedID = selectedID
        self.onNewChat = onNewChat
        self.onDelete = onDelete
    }

    public var body: some View {
        List(selection: $selectedID) {
            ForEach(conversations) { conversation in
                conversationRow(conversation)
                    .tag(conversation.id)
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("Hermes")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: onNewChat) {
                    Label("Nieuwe chat", systemImage: "plus")
                }
            }
        }
    }

    private func conversationRow(_ conversation: ConversationEntity) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title)
                .font(.body)
                .lineLimit(1)

            Text(conversation.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            if selectedID == conversation.id {
                selectedID = nil
            }
            onDelete(conversation)
        }
    }
}
