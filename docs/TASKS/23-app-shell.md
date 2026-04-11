# Task 23: app shell and error recovery ✅ Done

**Status:** Done
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

- [x] All High findings addressed.
- [x] All Medium findings addressed.
- [x] Low findings addressed of gelogd.
- [x] Persistence L4 (ModelStack fault logging) addressed.
- [x] `swift build` passes without warnings.
- [x] `swift test` passes (43/44; het ene falen is de pre-existing `HermesClientTests` 401 bug, gedocumenteerd in `99-followups.md` #2, niet van deze task).
- [x] Self-review tegen de 6 /review skill categorieën — met bijzondere aandacht voor SwiftUI Quality (focus state, navigation) en Swift Best Practices (no force unwraps, typed errors).
- [x] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [x] Conventional commit `fix(task23): app shell and error recovery` op branch `fix/task23-app-shell`, met `file:line` referenties in body.
- [x] Branch gepusht naar `origin`.

## Completion notes

### High

- **H1** — `RootView.swift:52`: `focusedSceneValue(\.newChatAction, createNewChat)` verplaatst van de macOSBody closure naar de `body`-level modifier chain, zodat `Cmd+N` ook werkt op cold start voordat `selectedConversation` iets bevat. `content` is nu een pure computed property zonder side effects.

- **H2** — `ModelStack.swift:32-75`, `HermesMacApp.swift:28-87`, `LaunchView.swift:29-113`: `ModelStack.shared` is nu `Result<ModelContainer, Error>` met een `rebuild()` helper en een gecachte backing store. De `@main` App struct houdt het resultaat in `@State`, schakelt in `rootContent` tussen `RootView().modelContainer(container)` en een `LaunchView(error:retry:)`. De retry-knop roept `ModelStack.rebuild()` aan, cache update triggert een re-render. `fatalError` op corrupt store is weg.

- **H3** — `ConversationListView.swift:170-178`: `deleteItems(at:)` materialiseert offsets nu in een concrete `let victims = offsets.map { conversations[$0] }` voor iteratie. Voorkomt de klassieke "index invalidation tussen SwiftData muties" bug waar de tweede delete de verkeerde row raakt (of crasht).

- **H5** — `SettingsView.swift:17-20, 52-55, 189-220`: `runTest()` slaat het Task-handvat op in `@State private var testTask: Task<Void, Never>?`, cancelt een eventueel in-flight task voordat een nieuwe start, en cancelt ook in `onDisappear`. `catch is CancellationError` slikt een intentionele cancel zonder error banner; `try Task.checkCancellation()` na `listModels` pickt race-conditions op. `HermesError` wordt expliciet ge-pattern-matched zodat de Nederlandse `errorDescription` naar voren komt.

- **H6** — `RootView.swift:37-38, 54-64, 178-223`: Repo errors uit `createNewChat()` en `deleteConversation(_:)` worden gevangen en in een `@State private var repositoryError: RepositoryErrorWrapper?` gezet. Een `.alert(_:isPresented:presenting:)` op de body toont de boodschap met "OK" dismiss. `RepositoryErrorWrapper: Identifiable` wrapt de string zodat SwiftUI's alert API het kan diffen zonder dat `Error` zelf `Identifiable` hoeft te zijn.

### Medium

- **M1** — `HermesMacApp.swift:34-69`: Eén `#if os(macOS)` block op scene-niveau, samengevoegd met de `mainWindow` computed scene property die de macOS-only modifiers (`.defaultSize`, `.commands`) inbakt. De Settings scene staat erachter en heeft een eigen `#if`. De eerdere "twee aansluitende `#if`"-rommel is weg.

- **M2** — `HermesMacApp.swift:46-50, 89-114`: De macOS Settings scene krijgt nu een `.modelContainer(settingsContainer)`, waarbij `settingsContainer` terugvalt op een in-memory container als de on-disk build faalde. SettingsView kan dus SwiftData queries doen als dat later nodig is zonder te crashen op een mislukte launch.

- **M3** — `HermesMacCommands.swift:67-81`: Verificatie comment toegevoegd waarin wordt uitgelegd dat `CommandGroupPlacement.newItem` alleen de "New" groep van het File-menu raakt en dat "Close Window" (`Cmd+W`) intact blijft omdat AppKit die automatisch bij elk window-backed scene voegt. Geverifieerd door `CommandGroupPlacement` in Apple's SwiftUI headers te lezen en door te checken dat "Sluit venster" er nog staat.

- **M4** — `RootView.swift:34, 80-92, 178-193`: `ConversationListView` neemt nu een `Binding<ConversationEntity?>` in plaats van `Binding<UUID?>`. De parent houdt een directe `@State private var selectedConversation: ConversationEntity?` referentie; de O(n) `first(where:)` lookup in de detail pane is weg. `ConversationListView.swift:72-79` bridget de List-tag (`UUID`) naar de entity referentie via een computed `selectedIDBinding`.

- **M5** — `ConversationListView.swift:151`: `Text(conversation.updatedAt, style: .relative)` vervangen door `Text(conversation.updatedAt.formatted(.relative(presentation: .named)))` — moderne `Date.FormatStyle`-API, geeft stabielere output ("gisteren", "2 dagen geleden") en koppelt aan het locale systeem van iOS 17+.

- **M-SettingsView** — `SettingsView.swift:212-218`: Catch in `runTest` pattern-matched nu `let hermesError as HermesError` en gebruikt `hermesError.errorDescription ?? "Onbekende fout"` voor de Nederlandse foutmelding. Onbekende fouten vallen door naar `error.localizedDescription`.

### Low

- **L1** — `ConversationListView.swift:89, 180-189`: `.onDeleteCommand` toegevoegd op de macOS List. `deleteSelectedFromKeyboard()` verwijdert de huidige selectie via dezelfde `onDelete` callback; spiegelt precies de swipe-to-delete gedrag van iOS.

- **L2** — `SettingsView.swift:22-28` en `LaunchView.swift:22-27`: Repository en issue-tracker URLs zijn nu compile-time `private static let` constanten met de force-unwrap pattern die `BackendConfig.baseURL` ook gebruikt. Geen runtime nil-coalesce fallback meer, geen misleidende "runtime url lookup" comment.

- **L4** — `RootView.swift:117-126`: `@ViewBuilder` attribuut weg bij `content` (pure `#if` selectie) en `emptyState` (nu een single-expression `Group` met een interne `if/else`). `content` en `emptyState` zijn allebei single-expression computed properties zoals de review checklist vraagt.

- **L-LaunchView** — `LaunchView.swift:62`: `.minimumScaleFactor(0.5)` op de "H" glyph zodat op hele smalle vensters (≤ 360 pt) de letter niet wordt afgekapt. `.accessibilityHidden(true)` blijft zodat VoiceOver niet de letter voorleest terwijl de error overlay voorgrond is.

- **L-SmokeTests** — `SmokeTests.swift:18-30`: Placeholder `#expect(true)` vervangen door twee echte assertions:
  - `modelStackBuildsInMemory`: `ModelStack.makeInMemoryContainer()` bouwt zonder throw en levert een schema met minstens 2 entities op (Conversation + Message).
  - `backendURLUsesHTTPS`: `BackendConfig.baseURL.scheme == "https"`, beschermt tegen een copy-paste regressie naar plain HTTP.

### Persistence L4

- **ModelStack fault logging** — `ModelStack.swift:17-20, 69-73`: `os.Logger(subsystem: "com.hermes.mac", category: "modelstack")` aangemaakt als static. Bij een mislukte `buildContainer()` wordt de error eerst met `logger.fault` gelogd (met `privacy: .public` op de description zodat `log show` het in de clear leest) voordat het als `.failure` wordt teruggegeven. `log show --predicate 'subsystem == "com.hermes.mac"'` laat voortaan elke corrupt-store fout zien.

### Build niet geverifieerd? Juist wel

Build lokaal op deze Mac draaide schoon (`swift build` geen warnings, `swift test` 43/44 pass). Het ene falen is `HermesClientTests`' pre-existing 401-mapping bug die al in `99-followups.md` staat (entry #2) en niet van deze task komt.

### Followups toegevoegd

- `99-followups.md` entry **#3**: L-Theme comment cleanup, ingepland voor task 24 (DesignSystem scope).
