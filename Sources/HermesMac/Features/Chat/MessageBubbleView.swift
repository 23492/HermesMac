import MarkdownUI
import SwiftUI

/// A single message bubble with role-based alignment and color.
///
/// User messages are rendered as plain `Text` (what the user typed is not
/// markdown). Assistant messages are rendered as rich markdown via
/// ``MarkdownUI`` so headings, code blocks and inline code look right.
public struct MessageBubbleView: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: MessageEntity

    public init(message: MessageEntity) {
        self.message = message
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
}
