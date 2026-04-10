import MarkdownUI
import SwiftUI

/// A single message bubble with role-based alignment and color.
///
/// User messages are rendered as plain `Text` (what the user typed is not
/// markdown). Assistant messages are rendered as rich markdown via
/// ``MarkdownUI`` so headings, code blocks and inline code look right.
///
/// A long-press (iOS) / right-click (macOS) context menu exposes per-message
/// actions: copy for every message, regenerate for the last assistant
/// message, delete for every message. The surrounding view wires the
/// callbacks to ``ChatModel``.
public struct MessageBubbleView: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: MessageEntity
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onRegenerate: (() -> Void)?

    public init(
        message: MessageEntity,
        onCopy: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRegenerate: (() -> Void)? = nil
    ) {
        self.message = message
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onRegenerate = onRegenerate
    }

    private var isUser: Bool { message.role == "user" }

    /// Displayed content, falling back to a single space so an empty bubble
    /// still has a sensible height while a response is streaming in.
    private var displayContent: String {
        message.content.isEmpty ? " " : message.content
    }

    public var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            bubbleContent
                .padding(Theme.bubblePadding)
                .background(isUser ? Theme.userBubble : Theme.assistantBubble)
                .foregroundStyle(isUser ? Theme.userBubbleText : .primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))
                .contextMenu { menuContent }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(displayContent)
                .textSelection(.enabled)
        } else {
            Markdown(displayContent)
                .markdownTheme(colorScheme == .dark ? .hermesDark : .hermesLight)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        Button {
            onCopy()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if let onRegenerate, !isUser {
            Button {
                onRegenerate()
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
