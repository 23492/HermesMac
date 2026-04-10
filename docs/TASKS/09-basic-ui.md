# Task 09: Basic UI — ChatView + input + conversation list

**Status:** Niet gestart
**Dependencies:** Task 08
**Estimated effort:** 45 min

## Doel

Implementeer de minimal viable UI: een conversation list aan de linkerkant, een chat view rechts, en een input composer onderaan. Geen markdown, geen styling subtleties. Alleen kale `Text` in bubbles.

Na deze task heeft Kiran voor het eerst een werkende app waar hij een bericht kan versturen en een antwoord kan zien streamen.

## Scope

### In scope
- `ConversationListView.swift` — lijst met conversations, plus "New chat" knop
- `ChatView.swift` — message list + composer
- `MessageBubbleView.swift` — eenvoudige bubble met role-based kleur
- `MessageComposerView.swift` — tekstveld + send knop
- Integratie met `ChatModel` en `ConversationRepository` via `@Environment`
- `ContentView` upgrade: `NavigationSplitView` op macOS, `NavigationStack` op iOS

### Niet in scope
- Markdown rendering (task 10)
- Syntax highlighting (task 11)
- Context menus (task 12)
- Settings sheet (task 15)
- Polished empty states (task 17)

## Design

```
┌──────────────────────┬─────────────────────────────────────┐
│ ☰ Hermes             │  ←  Chat title                      │
├──────────────────────┼─────────────────────────────────────┤
│ + New chat           │                                     │
│                      │   [user bubble]                     │
│ [Chat 1]             │                      [asst bubble]  │
│ [Chat 2]             │                                     │
│ [Chat 3]             │   [user bubble]                     │
│                      │                      [asst bubble]  │
│                      │                                     │
│                      ├─────────────────────────────────────┤
│                      │ [     tekstveld     ] [→]           │
└──────────────────────┴─────────────────────────────────────┘
```

Alle kleuren en paddings via `Theme` uit task 01.

## Implementation hints

- Gebruik `NavigationSplitView` met `NavigationSplitViewVisibility.all` als default op macOS
- Op iOS gebruik `NavigationStack` binnen een root view
- Message list: `ScrollViewReader` om naar onderen te scrollen tijdens streaming
- Composer: `TextField` met `axis: .vertical` voor multi-line op iOS 17+
- Send knop: disabled als `inputText.isEmpty` of `isStreaming`
- Loading indicator: `ProgressView()` naast composer tijdens streaming
- Error banner: simpele `Text` met background als `errorMessage != nil`

## Code structure

```swift
// Feature file tree:
Sources/HermesMac/Features/
├── Chat/
│   ├── ChatView.swift            // main chat view
│   ├── MessageBubbleView.swift   // individual bubble
│   └── MessageComposerView.swift // input bottom bar
├── Sidebar/
│   └── ConversationListView.swift // list + new button
└── Root/
    └── RootView.swift             // NavigationSplitView shell
```

De `RootView` vervangt de huidige placeholder `ContentView` uit task 00.

## ChatView skeleton

```swift
import SwiftUI
import SwiftData

public struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    let conversation: ConversationEntity

    @State private var model: ChatModel?

    public init(conversation: ConversationEntity) {
        self.conversation = conversation
    }

    public var body: some View {
        Group {
            if let model {
                chatContent(model: model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(conversation.title)
        .task(id: conversation.id) {
            // Construct the ChatModel when the conversation changes
            let repo = ConversationRepository(context: modelContext)
            let client = HermesClient()
            let selector = EndpointSelector()
            self.model = ChatModel(
                conversation: conversation,
                client: client,
                selector: selector,
                settings: settings,
                repository: repo
            )
        }
    }

    @ViewBuilder
    private func chatContent(model: ChatModel) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.messages) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.messages.last?.content) { _, _ in
                    if let last = model.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = model.errorMessage {
                errorBanner(error)
            }

            MessageComposerView(
                text: Binding(
                    get: { model.inputText },
                    set: { model.inputText = $0 }
                ),
                isStreaming: model.isStreaming,
                onSend: { Task { await model.send() } },
                onCancel: { model.cancel() }
            )
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.red.opacity(0.9))
    }
}
```

## Done when

- [ ] Je kan in Xcode de app bouwen en op iOS simulator + macOS runnen
- [ ] Je ziet een sidebar met conversations
- [ ] Je kan een nieuwe chat aanmaken
- [ ] Je kan een bericht sturen (handmatig in settings je API key invoeren via debugger of hardcode tijdelijk)
- [ ] Je ziet een antwoord streamen in plain text
- [ ] Commit: `feat(task09): minimal chat UI with streaming`

## Open punten

- Settings UI komt pas in task 15. Tot die tijd mag je voor testen je API key hardcoden in AppSettings init, maar **haal dat terug weg** voor je commit.
- Als Kiran wil testen vóór task 15, zeg dan dat hij lldb-expression kan gebruiken:
  `expression -- AppSettings.shared.apiKey = "kG3Bw9..."`
