# Task 23: app shell and error recovery

**Status:** Niet gestart
**Dependencies:** Task 17 (error states — shipped)
**Estimated effort:** 60–90 min

## Doel

App-shell robuust maken: `ModelStack` build failures zichtbaar in plaats van fatal, keyboard shortcuts werken op cold start, sidebar delete is safe, SettingsView runTest cancelbaar, en errors in create/delete conversation sichtbaar in een alert.

## Context

Code review van 2026-04-11 leverde in App shell 6 High, 5 Medium en 5 Low findings op, plus één persistence L4 (ModelStack fatalError) die hier logisch thuishoort. Deze task is de grootste qua file-breadth maar elk fix is geïsoleerd.

Deze task loopt **parallel** met Tasks 19–22, 24. Files: alles in `App/*`, `Features/Root/*`, `Features/Sidebar/*`, `Features/SettingsPane/*`, plus `Core/Persistence/ModelStack.swift` en `Tests/HermesMacTests/SmokeTests.swift`.

## Scope

### In scope

**High**
- **H1** — `HermesMacApp.swift`: `focusedSceneValue(\.newChatAction, createNewChat)` staat in de `macOSBody` closure maar afhankelijk van `selectedConversation`. Verplaats naar `RootView.body`-level zodat `Cmd+N` ook werkt op cold start (voordat een conversation is geselecteerd).
- **H2** — `HermesMacApp.swift` + `Core/Persistence/ModelStack.swift`: `ModelStack.shared` build wordt in `@main` init aangeroepen zonder fallback — als het faalt crasht de app. Wrap in `Result`; in `LaunchView` render een error overlay met een "Probeer opnieuw" knop en een "Verzend logs" link. Als build slaagt, door naar `RootView`.
- **H3** — `ConversationListView.swift`: `deleteItems(at offsets:)` itereert `for idx in offsets { repo.delete(conversations[idx]) }`, dat is onveilig omdat de List `conversations` muteert tussen indices door. Materialize eerst: `let victims = offsets.map { conversations[$0] }; for c in victims { repo.delete(c) }`.
- **H5** — `SettingsView.swift`: `runTest()` fire-and-forget Task zonder cancellation. Sla het op als `@State private var testTask: Task<Void, Never>?`, cancel in `onDisappear`, en handle `CancellationError` in de catch (geen error banner).
- **H6** — `RootView.swift`: `createNewChat` en `deleteConversation` gooien repo errors in het niets. Catch en set `@State private var repositoryError: ConversationRepositoryError?`; toon in een `.alert(isPresented:)`.

**Medium**
- **M1** — `HermesMacApp.swift`: twee opeenvolgende `#if os(macOS) ... #endif` blocks in `body` — merge tot één.
- **M2** — `HermesMacApp.swift`: de macOS `Settings` scene heeft geen `.modelContainer(ModelStack.shared.container)` — preemptief toevoegen zodat SettingsView SwiftData queries kan doen als dat nodig blijkt.
- **M3** — `HermesMacApp.swift`: `CommandGroup(replacing: .newItem)` killt mogelijk ook "Close Window" — verifieer met een comment en restore als dat zo is.
- **M4** — `HermesMacApp.swift` `macOSBody.detail`: `conversations.first(where: { $0.id == selectedID })` is een scan. Vervang door `@State var selectedConversation: ConversationEntity?` die direct een referentie houdt.
- **M5** — `ConversationListView.swift`: `Text(conversation.updatedAt, style: .relative)` is verouderd. Gebruik `conversation.updatedAt.formatted(.relative(presentation: .named))`.
- **M-SettingsView** — `SettingsView.swift`: in `runTest`'s catch pattern-match op `HermesError` en gebruik `errorDescription`. Nu valt het op een generieke `"Onbekende fout"`.

**Low**
- **L1** — `ConversationListView.swift` (macOS branch): voeg `.onDeleteCommand` toe zodat Delete-key in de sidebar een row verwijdert (spiegelt `onDelete` van iOS lijst).
- **L2** — `HermesMacApp.swift` of waar `repoURL` gebruikt wordt: vervang runtime fallback door `private static let repositoryURL = URL(string: "https://github.com/kiran/HermesMac")!` (compile-time). Opruimen van misleidende comment die zegt "runtime url lookup".
- **L4** — `RootView.swift`: `@ViewBuilder var emptyState: some View { ... }` dropt de attribuut — het is een single-expression computed property.
- **L-LaunchView** — `LaunchView.swift`: `.minimumScaleFactor(0.5)` op het glyph-icon.
- **L-SmokeTests** — `SmokeTests.swift`: vervang `#expect(true)` placeholder door echte assertions: `ModelStack.makeInMemoryContainer()` builds zonder throw; `BackendConfig.baseURL.scheme == "https"`.

**Persistence L4**
- In `ModelStack.swift` (die H2 boven al raakt): voeg een `Logger(subsystem:category:).fault("ModelStack build failed: \(error)")` log call toe vóór de recovery path. Gebruikt `os.Logger`.

### Niet in scope

- **Theme comment cleanup (L-Theme)** — zit in DesignSystem → Task 24.
- **Chat Ui/logic** — Task 22.
- **Networking** — Task 19.
- **Settings / Keychain logic** — Task 21 (alleen SettingsView run-test surfacing is hier).
- **Files**: alles buiten `App/*`, `Features/Root/*`, `Features/Sidebar/*`, `Features/SettingsPane/*`, `Core/Persistence/ModelStack.swift`, `Tests/HermesMacTests/SmokeTests.swift`.

## Implementation

### Files to modify

- `Sources/HermesMac/App/HermesMacApp.swift`
- `Sources/HermesMac/App/HermesMacCommands.swift`
- `Sources/HermesMac/Features/Root/RootView.swift`
- `Sources/HermesMac/Features/Root/LaunchView.swift`
- `Sources/HermesMac/Features/Sidebar/ConversationListView.swift`
- `Sources/HermesMac/Features/SettingsPane/SettingsView.swift`
- `Sources/HermesMac/Core/Persistence/ModelStack.swift`
- `Tests/HermesMacTests/SmokeTests.swift`

### Approach

- **H1**: `focusedSceneValue` op `RootView.body` attachen. `createNewChat` blijft een method op de view, gebruikt `@Environment(\.modelContext)` of de shared repo.
- **H2**: `ModelStack.swift`:

  ```swift
  public static let shared: Result<ModelStack, Error> = {
      do {
          return .success(try ModelStack())
      } catch {
          Logger(subsystem: "com.hermes.mac", category: "modelstack")
              .fault("ModelStack build failed: \(error.localizedDescription, privacy: .public)")
          return .failure(error)
      }
  }()
  ```

  `LaunchView` krijgt een `error: Error?` parameter; bij non-nil toont het de overlay en een retry knop die `ModelStack.shared` opnieuw probeert op te halen.

- **H3**: `deleteItems(at offsets: IndexSet)` vervangen door `let victims = offsets.map { conversations[$0] }; for c in victims { try? repo.delete(c) }` (errors gaan richting repo error state via H6).

- **H5**: SettingsView:

  ```swift
  @State private var testTask: Task<Void, Never>?

  private func runTest() {
      testTask?.cancel()
      testTask = Task { [weak viewModel = self.viewModel] in
          // existing logic
      }
  }

  var body: some View {
      ... .onDisappear { testTask?.cancel() }
  }
  ```

- **H6**: RootView pattern-match catch, alert bindt op `repositoryError != nil`.

- **M3**: verify met een korte comment; als restore nodig, voeg `CommandGroup(after: .newItem) { Button("Close Window") { ... } }` toe.

- **L-SmokeTests**: `@Test func modelStackBuildsInMemory() throws { let container = try ModelStack.makeInMemoryContainer(); #expect(container.schema.entities.count > 0) }`. Voeg de helper `makeInMemoryContainer` toe in `ModelStack.swift` (public of internal).

## Verification

```
cd /Users/kiranknoppert/Documents/HermesMac/.claude/worktrees/task23-app-shell
swift build 2>&1 | tail -20
swift test --filter SmokeTests 2>&1 | tail -20
```

Expected: build zonder warnings. SmokeTests slagen met echte assertions.

## Done when

- [ ] All High findings addressed.
- [ ] All Medium findings addressed.
- [ ] Low findings addressed of gelogd.
- [ ] Persistence L4 (ModelStack fault logging) addressed.
- [ ] `swift build` passes without warnings.
- [ ] `swift test` passes.
- [ ] Self-review tegen de 6 /review skill categorieën — met bijzondere aandacht voor SwiftUI Quality (focus state, navigation) en Swift Best Practices (no force unwraps, typed errors).
- [ ] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [ ] Conventional commit `fix(task23): app shell and error recovery` op branch `fix/task23-app-shell`, met `file:line` referenties in body.
- [ ] Branch gepusht naar `origin`.
