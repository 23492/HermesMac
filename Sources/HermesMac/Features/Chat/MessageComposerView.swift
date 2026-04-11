import SwiftUI

/// Bottom bar with a multi-line text field, send button, and streaming cancel.
public struct MessageComposerView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    /// External focus binding so ``ChatView`` can drive keyboard focus
    /// from menu commands (Cmd+K on macOS) while still owning the
    /// `@FocusState` itself.
    private let focusBinding: FocusState<Bool>.Binding

    public init(
        text: Binding<String>,
        isStreaming: Bool,
        focus: FocusState<Bool>.Binding,
        onSend: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._text = text
        self.isStreaming = isStreaming
        self.focusBinding = focus
        self.onSend = onSend
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField(String(localized: "composer.placeholder", defaultValue: "Bericht..."), text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...8)
                    .padding(8)
                    .background(Theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused(focusBinding)
                    .onSubmit {
                        if !isStreaming && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }

                if isStreaming {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)

                        Button(action: onCancel) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .gray
                                    : .accentColor
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
