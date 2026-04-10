import SwiftUI

// MARK: - Focused values

/// Closure type used by every menu command in this file.
///
/// Explicitly `@MainActor` so the closures can capture view state and
/// call `@MainActor`-isolated methods (``ChatModel``, ``ConversationRepository``)
/// without compiler complaints under Swift 6 strict concurrency.
typealias MenuActionClosure = @MainActor () -> Void

private struct NewChatActionKey: FocusedValueKey {
    typealias Value = MenuActionClosure
}

private struct CancelStreamingActionKey: FocusedValueKey {
    typealias Value = MenuActionClosure
}

private struct FocusComposerActionKey: FocusedValueKey {
    typealias Value = MenuActionClosure
}

extension FocusedValues {

    /// Callback to create a new empty conversation, published by
    /// ``RootView``. Nil while no window is focused.
    var newChatAction: MenuActionClosure? {
        get { self[NewChatActionKey.self] }
        set { self[NewChatActionKey.self] = newValue }
    }

    /// Callback to cancel the active streaming response, published by
    /// ``ChatView`` when a chat is selected. Nil when no chat is open.
    var cancelStreamingAction: MenuActionClosure? {
        get { self[CancelStreamingActionKey.self] }
        set { self[CancelStreamingActionKey.self] = newValue }
    }

    /// Callback to move keyboard focus to the message composer,
    /// published by ``ChatView``. Nil when no chat is open.
    var focusComposerAction: MenuActionClosure? {
        get { self[FocusComposerActionKey.self] }
        set { self[FocusComposerActionKey.self] = newValue }
    }
}

// MARK: - macOS menu bar commands

#if os(macOS)

/// macOS menu bar commands: new chat, focus composer, stop streaming.
///
/// Commands live at the scene level and cannot reach view state directly.
/// We bridge them to views via ``FocusedValues``: each view that wants to
/// handle a command publishes its callback with `.focusedSceneValue(...)`,
/// and the matching `@FocusedValue` on this struct reads it back. Commands
/// are automatically disabled when the corresponding value is `nil`,
/// i.e. when no view has offered to handle them.
struct HermesMacCommands: Commands {

    @FocusedValue(\.newChatAction) private var newChat
    @FocusedValue(\.cancelStreamingAction) private var cancelStreaming
    @FocusedValue(\.focusComposerAction) private var focusComposer

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nieuwe chat") {
                newChat?()
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(newChat == nil)
        }

        CommandMenu("Chat") {
            Button("Focus bericht") {
                focusComposer?()
            }
            .keyboardShortcut("k", modifiers: [.command])
            .disabled(focusComposer == nil)

            Button("Stop streaming") {
                cancelStreaming?()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(cancelStreaming == nil)
        }
    }
}

#endif
