# Task 19: networking robustness

**Status:** Niet gestart
**Dependencies:** Task 17 (error states — shipped)
**Estimated effort:** 60–90 min

## Doel

De Networking-laag robuust maken tegen realistische failure modes: in-stream API errors, gecancelde streams, niet-gelezen error bodies en ontbrekende tests.

## Context

Code review van 2026-04-11 heeft in de Networking-module 1 Critical, 4 High, 5 Medium en 4 Low findings opgeleverd. Deze task pakt alle findings uit die module op in één branch. Belangrijk: `99-followups.md` entry #2 wordt afgesloten door H3 hieronder (error body drain zorgt dat 401 een echte `httpStatus` gooit).

Deze task loopt **parallel** met Tasks 20–24. Alleen files in `Core/Networking/` en de bijbehorende tests in `Tests/HermesMacTests/HermesClientTests.swift` en `SSEParserTests.swift` mogen worden aangeraakt.

## Scope

### In scope

**Critical**
- **C1** — `HermesClient.swift`: `CancellationError` wordt heruitgeworpen als `HermesError.transport`, waardoor een nette cancel lijkt op een netwerkfout. Vang `CancellationError` en `URLError(.cancelled)` apart af en laat ze onveranderd doorlopen (re-throw zonder wrapping).

**High**
- **H1** — `ChatCompletion.swift` + `HermesError.swift` + `HermesClient.streamChatCompletion`: de stream negeert `{"error": {...}}` frames die de backend mid-stream kan sturen. Voeg `APIError` toe aan `ChatCompletionChunk`, voeg `HermesError.inStream(String)` toe en gooi die zodra een chunk een error bevat. Closes `99-followups.md` #2.
- **H2** — `HermesClient.swift`: huidige `try?` op `JSONDecoder().decode(ChatCompletionChunk.self, ...)` slikt decode-fouten. Vervang door expliciet `do/catch` dat `HermesError.decoding(Error)` gooit.
- **H3** — `HermesClient.streamChatCompletion`: non-2xx streaming responses werpen `HermesError.httpStatus(code, nil)` zonder body. Drain eerst tot 4 KB van de response body en geef die mee aan de error. Dit sluit meteen `99-followups.md` #2 (de 401 test in `HermesClientTests` krijgt nu een echte status error terug).
- **H4** — `HermesClientTests.swift`: streaming path heeft geen tests. Voeg minimaal deze toe met `MockURLProtocol`:
  - happy path met één delta frame
  - `[DONE]` sentinel
  - `finish_reason: "stop"`
  - cancelation via `Task.cancel()` — moet `CancellationError` gooien
  - in-stream `{error:{...}}` — moet `HermesError.inStream` gooien
  - 401 streaming — moet `HermesError.httpStatus(401, body)` gooien

**Medium**
- **M1** — `SSELineStream.swift`: voeg een regression test toe die `data:` frame-ordering garandeert wanneer meerdere frames in één buffer zitten.
- **M2** — `SSELineStream.swift`: Cloudflare edge stuurt soms `\r\n`. Voeg `\r\n` tolerantie en een test toe.
- **M3** — `SSELineStream.swift`: laatste SSE frame zonder trailing blank line wordt nu niet ge-emit bij EOF. Fix en test.
- **M4** — `ChatCompletion.swift`: decoder strategy (snake_case) is impliciet; voeg doc comment + unit-covered `JSONDecoder.KeyDecodingStrategy` toe.
- **M5** — `HermesClient.swift`: platform-availability check op `URLSession.bytes(for:)` annoteren of gatekeepen.

**Low**
- **L1** — `HermesClient.swift`: unwrap `URLError` in transport branch zodat `URLError.Code` onderscheidbaar is.
- **L2** — `HermesClient.swift`: voeg `CustomStringConvertible` toe aan `HermesEndpoint` die de host logt maar API-key-achtige queries redact.
- **L3** — `SSELineStream.swift`: fieldless SSE lines (alleen `: comment`) negeren met inline comment en test.
- **L4** — `HermesError.swift`: maak `errorDescription` exhaustive over nieuwe cases (inStream).

### Niet in scope

- `Core/Persistence/*` — Task 20.
- `Core/Settings/*` — Task 21.
- `Features/Chat/*` (incl. `HermesClient` call sites) — Task 22.
- `App/*`, `Features/Root/*`, `Features/Sidebar/*`, `Features/SettingsPane/*`, `Core/Persistence/ModelStack.swift` — Task 23.
- `DesignSystem/*` — Task 24.

Alles wat een API-signature verandering van `streamChatCompletion` (zoals per-call endpoint injectie, Chat review H4) raakt: naar `99-followups.md`. Pure toevoegingen aan het error type zijn hier prima.

## Implementation

### Files to modify

- `Sources/HermesMac/Core/Networking/HermesError.swift`
- `Sources/HermesMac/Core/Networking/HermesClient.swift`
- `Sources/HermesMac/Core/Networking/ChatCompletion.swift`
- `Sources/HermesMac/Core/Networking/SSEEvent.swift`
- `Sources/HermesMac/Core/Networking/SSELineStream.swift`
- `Tests/HermesMacTests/HermesClientTests.swift`
- `Tests/HermesMacTests/SSEParserTests.swift`

### Approach

Per finding:

- **C1**: in de outer `do { ... } catch { ... }` van `streamChatCompletion`: eerst `catch is CancellationError { throw }`, daarna `catch let urlErr as URLError where urlErr.code == .cancelled { throw CancellationError() }`, en pas daarna `catch { throw .transport(error) }`.
- **H1**: nieuwe case `case inStream(String)` in `HermesError`. In `ChatCompletionChunk` een optionele `error: APIError?` met `struct APIError: Decodable { let message: String; let type: String?; let code: String? }`. In de stream loop: als `chunk.error != nil { throw HermesError.inStream(chunk.error!.message) }`.
- **H2**: vervang `guard let chunk = try? decoder.decode(...)` door `let chunk: ChatCompletionChunk; do { chunk = try decoder.decode(...) } catch { throw HermesError.decoding(error) }`.
- **H3**: in de streaming path na `HTTPURLResponse` check, als non-2xx: `var body = Data(); for try await chunk in bytes { body.append(chunk); if body.count >= 4096 { break } }; throw .httpStatus(statusCode, String(data: body, encoding: .utf8))`.
- **H4**: tests zoals hierboven. Hergebruik bestaande `MockURLProtocol`-patroon.
- **M1–M3**: in `SSELineStream.swift` en `SSEParserTests.swift`. Voor EOF: na de `for try await` loop nog `flushPending()` aanroepen.
- **M4**: `private let decoder: JSONDecoder = { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }()` met doc comment.
- **M5**: `@available(macOS 12.0, iOS 15.0, *)` of soortgelijke availability, gemaxxed tegen onze minimum deployment targets (macOS 14 / iOS 17).

## Verification

```
cd /Users/kiranknoppert/Documents/HermesMac/.claude/worktrees/task19-networking
swift build 2>&1 | tail -20
swift test --filter HermesClientTests 2>&1 | tail -30
swift test --filter SSEParserTests 2>&1 | tail -30
```

Expected: build succeeds without warnings. New streaming tests pass. SSE parser tests pass incl. nieuwe regression tests.

## Done when

- [ ] All High and Medium findings addressed.
- [ ] Streaming tests toegevoegd (happy, DONE, finish_reason, cancel, in-stream error, 401).
- [ ] SSE parser regression tests voor ordering, `\r\n`, EOF, fieldless.
- [ ] `99-followups.md` entry #2 kan worden afgesloten door de main agent (H3 fix).
- [ ] Low findings addressed of gelogd in `99-followups.md` als ze out-of-scope blijken.
- [ ] `swift build` passes without warnings.
- [ ] `swift test` passes (of specifieke failures gedocumenteerd).
- [ ] Self-review tegen de 6 /review skill categorieën (Swift Best Practices, SwiftUI Quality, Performance, Security, Architecture, Project-Specific Standards).
- [ ] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [ ] Conventional commit `fix(task19): networking robustness` op branch `fix/task19-networking`, met `file:line` referenties in body.
- [ ] Branch gepusht naar `origin`.
