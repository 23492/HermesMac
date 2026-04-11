import SwiftUI

/// Sidebar / conversation landing view.
///
/// On macOS this renders as a `List(selection:)` inside a
/// `NavigationSplitView` sidebar, with the parent view driving the
/// detail view from the selection binding. On iOS the same data is
/// presented as a `List` with `NavigationLink` rows so tapping pushes
/// the chat onto a `NavigationStack`; the `selectedID` binding is
/// unused there but kept in the public API for symmetry.
public struct ConversationListView: View {
    let conversations: [ConversationEntity]
    @Binding var selectedID: UUID?
    var onNewChat: () -> Void
    var onDelete: (ConversationEntity) -> Void

    #if os(iOS)
    /// Drives the iOS settings sheet. On macOS settings live in their
    /// own `Settings` scene (Cmd+,), so this state is unused there.
    @State private var showSettings = false
    #endif

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
        #if os(iOS)
        iosList
        #else
        macList
        #endif
    }

    // MARK: - macOS sidebar

    #if os(macOS)
    private var macList: some View {
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
    #endif

    // MARK: - iOS stack landing

    #if os(iOS)
    private var iosList: some View {
        List {
            ForEach(conversations) { conversation in
                NavigationLink(value: conversation.id) {
                    conversationRow(conversation)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("Hermes")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Label("Instellingen", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onNewChat) {
                    Label("Nieuwe chat", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Klaar") {
                                showSettings = false
                            }
                        }
                    }
            }
        }
    }
    #endif

    // MARK: - Row

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
