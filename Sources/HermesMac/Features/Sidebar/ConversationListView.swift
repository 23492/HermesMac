import SwiftUI

/// Sidebar / conversation landing view.
///
/// On macOS this renders as a `List(selection:)` inside a
/// `NavigationSplitView` sidebar, with the parent view driving the
/// detail view from the selection binding. On iOS the same data is
/// presented as a `List` with `NavigationLink` rows so tapping pushes
/// the chat onto a `NavigationStack`; the selection binding is
/// unused there but kept in the public API for symmetry.
public struct ConversationListView: View {
    let conversations: [ConversationEntity]
    @Binding var selection: ConversationEntity?
    var onNewChat: () -> Void
    var onDelete: (ConversationEntity) -> Void

    #if os(iOS)
    /// Drives the iOS settings sheet. On macOS settings live in their
    /// own `Settings` scene (Cmd+,), so this state is unused there.
    @State private var showSettings = false
    #endif

    public init(
        conversations: [ConversationEntity],
        selection: Binding<ConversationEntity?>,
        onNewChat: @escaping () -> Void,
        onDelete: @escaping (ConversationEntity) -> Void
    ) {
        self.conversations = conversations
        self._selection = selection
        self.onNewChat = onNewChat
        self.onDelete = onDelete
    }

    public var body: some View {
        #if os(iOS)
        iosList
            .overlay { if conversations.isEmpty { emptyListOverlay } }
        #else
        macList
            .overlay { if conversations.isEmpty { emptyListOverlay } }
        #endif
    }

    /// Shown in the sidebar/list when there are no conversations yet.
    /// Sits on top of an empty `List`, so it scrolls away as soon as
    /// the user creates their first chat.
    private var emptyListOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Geen chats nog")
                .font(.headline)
            Text("Tik op + om te beginnen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - macOS sidebar

    #if os(macOS)
    /// Two-way binding between the row selection (driven by
    /// `ConversationEntity.id`) and the parent's `selection` state.
    /// The List needs a `Hashable` tag type, and `UUID` is cheaper to
    /// diff than the model instance — we look up the real entity on
    /// set so the parent can hold a direct reference and skip an
    /// O(n) scan on every update.
    private var selectedIDBinding: Binding<UUID?> {
        Binding(
            get: { selection?.id },
            set: { newID in
                selection = conversations.first(where: { $0.id == newID })
            }
        )
    }

    private var macList: some View {
        List(selection: selectedIDBinding) {
            ForEach(conversations) { conversation in
                conversationRow(conversation)
                    .tag(conversation.id)
            }
            .onDelete(perform: deleteItems)
        }
        .onDeleteCommand(perform: deleteSelectedFromKeyboard)
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

            Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Delete

    /// Safe row deletion.
    ///
    /// We materialize the victims into a concrete array **before**
    /// touching the repository. The previous implementation iterated
    /// `for idx in offsets { ... conversations[idx] }`, which is
    /// unsafe: SwiftData mutations invalidate indices between calls,
    /// so the second delete would either target the wrong row or
    /// crash. Materializing once is O(k) memory for trivially small
    /// `k` — conversation selections are always tiny — and removes
    /// the class of bug entirely.
    private func deleteItems(at offsets: IndexSet) {
        let victims = offsets.map { conversations[$0] }
        for conversation in victims {
            if selection?.id == conversation.id {
                selection = nil
            }
            onDelete(conversation)
        }
    }

    #if os(macOS)
    /// Delete-key handler on macOS. Mirrors the swipe-to-delete
    /// affordance on iOS so power users can drive the sidebar from the
    /// keyboard.
    private func deleteSelectedFromKeyboard() {
        guard let target = selection else { return }
        selection = nil
        onDelete(target)
    }
    #endif
}
