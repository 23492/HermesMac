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
    let canRegenerate: Bool
    let onRegenerate: () -> Void

    /// Creates a bubble for a single message.
    ///
    /// - Parameters:
    ///   - message: The entity to render.
    ///   - onCopy: Invoked when the user picks "Copy" from the context menu.
    ///   - onDelete: Invoked when the user picks "Delete".
    ///   - canRegenerate: Whether the "Regenerate" action should be
    ///     offered. Passing `false` hides the menu item while keeping
    ///     the closure type fixed, so the caller does not have to
    ///     manage an optional callback.
    ///   - onRegenerate: Invoked when the user picks "Regenerate". Only
    ///     called when `canRegenerate` is `true`.
    public init(
        message: MessageEntity,
        onCopy: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        canRegenerate: Bool = false,
        onRegenerate: @escaping () -> Void = {}
    ) {
        self.message = message
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.canRegenerate = canRegenerate
        self.onRegenerate = onRegenerate
    }

    private var isUser: Bool { message.role == .user }

    /// `true` while an assistant placeholder has no content yet — the
    /// streaming response hasn't emitted its first chunk. Drives the
    /// typing indicator fallback for empty bubbles.
    private var isEmptyAssistantPlaceholder: Bool {
        !isUser && message.content.isEmpty
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
        if isEmptyAssistantPlaceholder {
            // L3: real typing indicator instead of a rendered space.
            // Keeps the bubble the right size *and* tells the user
            // the assistant is thinking.
            TypingIndicatorView()
        } else if isUser {
            Text(message.content)
                .textSelection(.enabled)
        } else {
            Markdown(message.content)
                .markdownTheme(colorScheme == .dark ? .hermesDark : .hermesLight)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        Button {
            onCopy()
        } label: {
            Label(String(localized: "contextMenu.copy", defaultValue: "Kopiëren"), systemImage: "doc.on.doc")
        }

        if canRegenerate, !isUser {
            Button {
                onRegenerate()
            } label: {
                Label(String(localized: "contextMenu.regenerate", defaultValue: "Opnieuw genereren"), systemImage: "arrow.clockwise")
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label(String(localized: "contextMenu.delete", defaultValue: "Verwijderen"), systemImage: "trash")
        }
    }
}

// MARK: - Typing indicator

/// Three-dot "typing" animation shown inside assistant bubbles that
/// are waiting for their first streamed chunk.
///
/// Each dot scales and fades on a staggered repeat-forever animation
/// so the group looks like it's bouncing in sequence. The animation
/// state is local `@State` and only runs while the view is on
/// screen — empty bubbles go away as soon as the first content chunk
/// arrives so this is automatic.
private struct TypingIndicatorView: View {
    private let dotCount = 3
    private let dotSize: CGFloat = 7
    private let animationDuration: Double = 0.6

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .opacity(isAnimating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: animationDuration)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .frame(minHeight: dotSize)
        .onAppear { isAnimating = true }
        .accessibilityLabel(String(localized: "chat.typingIndicator.a11y", defaultValue: "Aan het antwoorden"))
    }
}
