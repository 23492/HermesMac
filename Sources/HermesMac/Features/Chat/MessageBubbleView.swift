import SwiftUI

/// A single message bubble with role-based alignment and color.
public struct MessageBubbleView: View {
    let message: MessageEntity

    public init(message: MessageEntity) {
        self.message = message
    }

    private var isUser: Bool { message.role == "user" }

    public var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content.isEmpty ? " " : message.content)
                .textSelection(.enabled)
                .padding(Theme.bubblePadding)
                .background(isUser ? Theme.userBubble : Theme.assistantBubble)
                .foregroundStyle(isUser ? Theme.userBubbleText : .primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
