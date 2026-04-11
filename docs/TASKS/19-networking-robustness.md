# Task 19: networking robustness ✅ Done

**Status:** Done (2026-04-11)
**Branch:** `fix/task19-networking`
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

- [x] All High and Medium findings addressed.
- [x] Streaming tests toegevoegd (happy, DONE, finish_reason, cancel, in-stream error, 401).
- [x] SSE parser regression tests voor ordering, `\r\n`, EOF, fieldless.
- [x] `99-followups.md` entry #2 kan worden afgesloten door de main agent (H3 fix).
- [x] Low findings addressed of gelogd in `99-followups.md` als ze out-of-scope blijken.
- [x] `swift build` passes without warnings.
- [x] `swift test` passes (63 tests in 7 suites, allemaal groen).
- [x] Self-review tegen de 6 /review skill categorieën (Swift Best Practices, SwiftUI Quality, Performance, Security, Architecture, Project-Specific Standards).
- [x] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [x] Conventional commit `fix(task19): networking robustness` op branch `fix/task19-networking`, met `file:line` referenties in body.
- [x] Branch gepusht naar `origin`.

## Completion notes

Afgerond op 2026-04-11. Alle 14 findings uit de code review afgehandeld, plus
één extra pre-existing bug die tijdens het schrijven van de streaming tests
naar boven kwam (zie `99-followups.md` entry #4).

Verificatie: `swift build` (geen warnings), `swift test` → 63 tests in
7 suites groen. Waarvan 12 nieuwe streaming-tests in `HermesClientTests.swift`
en 11 nieuwe SSE regression-tests in `SSEParserTests.swift`.

### Per-finding wat/waarom

**C1 — CancellationError wordt niet meer gewrapped**
- Wat: `streamChatCompletion` vangt nu expliciet `CancellationError` en
  `URLError(.cancelled)` apart af vóór de algemene `catch`, zowel bij de
  initial `session.bytes(for:)` call als in de `pumpEvents` Task (`HermesClient.swift:123–126`, `HermesClient.swift:157–160`).
- Waarom: een cooperative `Task.cancel()` zou anders als `HermesError.transport`
  terugkomen en bij task 17's retry-logic een banner oproepen waar geen
  netwerk probleem was. Regression-getest in twee tests: `streamingCancellationDoesNotLeakAsTransport`
  en `streamingCancellationAtRequestTime` (`HermesClientTests.swift:153, 214`).

**H1 — In-stream `{"error": {...}}` frames worden nu gedetecteerd**
- Wat: `ChatCompletionChunk` heeft nu een geneste `APIError` struct en een
  custom `init(from:)` die `choices` defaults naar `[]` voor pure-error frames
  (`ChatCompletion.swift:59–120`). De pump loop gooit `HermesError.inStream(message)`
  zodra `chunk.apiError != nil` (`HermesClient.swift:214–216`).
- Waarom: voorheen werden error-frames ofwel als decode-fout afgedaan ofwel
  compleet genegeerd. Een rate-limit of mid-stream server crash leverde geen
  zinnige melding op. Test: `streamingInStreamError` (`HermesClientTests.swift:256`).

**H2 — Decode-fouten worden niet meer stilletjes geslikt**
- Wat: `try? decoder.decode(...)` is vervangen door een explicit `do/catch`
  die `HermesError.decoding(...)` gooit (`HermesClient.swift:207–211`).
- Waarom: een malformed chunk was onzichtbaar; de gebruiker kreeg een
  halve streaming response zonder enige hint dat er iets stuk was. Test:
  `streamingDecodeFailure` (`HermesClientTests.swift:317`).

**H3 — Error body wordt nu gedraind (tot 4 KB) bij non-2xx streaming**
- Wat: nieuwe helper `drainErrorBody(bytes:)` leest best-effort tot 4096
  bytes uit de byte stream en stopt die in `HermesError.httpStatus(code:body:)`
  (`HermesClient.swift:230–245`, aanroep op `HermesClient.swift:141`). De
  limiet ligt vast in `HermesClient.errorBodyByteLimit` (`HermesClient.swift:57`).
- Waarom: een 401 streaming response kwam voorheen als `httpStatus(401, nil)`
  terug, dus geen diagnosable melding. Sluit `99-followups.md` entry #2
  (de listModels 401 test liep vast om dezelfde reden). Test: `streaming401`
  (`HermesClientTests.swift:291`).

**H4 — Streaming tests toegevoegd**
- Wat: 9 nieuwe `@Test` cases in `HermesClientTests.swift` die met een
  `MockURLProtocol` (+ optionele `deliveryDelay`) de happy path, `[DONE]`
  sentinel, `finish_reason: "stop"`, cancel (×2), in-stream error, 401
  streaming, en decode failure dekken. `MockURLProtocol` is uitgesplitst
  naar zijn eigen file `Tests/HermesMacTests/MockURLProtocol.swift` om
  onder de 400-regel soft-limit te blijven. Suite is `.serialized` omdat
  de stub-registry shared static state gebruikt.
- Waarom: de streaming path had 0 automated coverage. Zonder deze tests
  was H1, H2, H3 en C1 niet te verifiëren.

**M1 — Frame ordering regression test**
- Wat: nieuwe test `frameOrderingPreserved` in `SSEParserTests.swift:104`
  stuurt 4 frames in één string door de parser en verifieert volgorde.
- Waarom: hypothetische toekomstige optimalisatie die events zou batchen
  mag de volgorde niet omdraaien.

**M2 — CRLF tolerantie**
- Wat: de parser dropt nu een trailing `\r` op elke regel voor-ie hem
  interpreteert (`SSELineStream.swift:68–71`), en `SSEByteLineSequence`
  dropt de `\r` al bij het splitten (`SSELineStream.swift:225–228`).
  Test: `crlfTolerated` (`SSEParserTests.swift:126`).
- Waarom: Cloudflare's edge serveert af en toe CRLF SSE en dat vervuilde
  anders de frame body met stray carriage returns.

**M3 — EOF zonder trailing blank line**
- Wat: na de `while` loop flusht de iterator een eventuele pending event
  éénmalig (geguard met `didFlushOnEOF` om double-emit te voorkomen),
  `SSELineStream.swift:113–118`. Twee tests: `finalFrameEmittedOnEOF` en
  `eofAfterCompleteAndPartial` (`SSEParserTests.swift:144, 156`).
- Waarom: per SSE spec implies EOF "dispatch". Voorheen werden partial
  responses bij een abrupt gesloten connectie stilletjes weggegooid.

**M4 — Decoder strategy documented en centraal geconfigureerd**
- Wat: `HermesClient` heeft nu één gedeelde `JSONDecoder` met
  `.convertFromSnakeCase` (`HermesClient.swift:60–63`). `ChatCompletionChunk`,
  `Choice`, `Delta`, `ModelInfo` laten hun expliciete `CodingKeys` vallen
  en leunen op de decoder strategy. Doc comment legt dit uit
  (`ChatCompletion.swift:11–19`, `HermesClient.swift:47–50`).
- Waarom: expliciete per-type `CodingKeys` was copy-paste en een bron van
  drift. Wire-fields als `finish_reason`/`owned_by` landen nu automatisch
  op Swift camelCase.

**M5 — Availability annotation**
- Wat: `streamChatCompletion` krijgt `@available(macOS 12.0, iOS 15.0, *)`
  (`HermesClient.swift:109`) om de SDK-floor voor `URLSession.bytes(for:)`
  expliciet te documenteren.
- Waarom: onze `Package.swift` targets (iOS 17 / macOS 14) overstijgen dat
  ruim, maar een linter-achtige guard is handig mocht iemand de minimums
  ooit verlagen.

**L1 — URLError wordt nu unwrapped in transport branch**
- Wat: `catch let urlError as URLError` komt nu vóór de algemene `catch`
  en neemt `localizedDescription` + `code.rawValue` mee
  (`HermesClient.swift:127–130` en `HermesClient.swift:163–166`).
- Waarom: onderscheid tussen DNS, TLS handshake, en timeout helpt bij
  diagnose zonder er een volledige error-classificatie op los te laten.

**L2 — `HermesEndpoint.description` redacts API key**
- Wat: `HermesEndpoint` conformt aan `CustomStringConvertible` en print
  alleen scheme + host + path, nooit de API key of query string
  (`HermesClient.swift:22–28`). Test: `endpointDescriptionRedacted`
  (`HermesClientTests.swift:347`).
- Waarom: voorkomt dat een developer per ongeluk `print(endpoint)` doet
  en daarmee een API key in de log dumpt.

**L3 — SSE comments worden genegeerd**
- Wat: regels die met `:` beginnen worden overgeslagen
  (`SSELineStream.swift:86–88`), en een bare `data` line zonder colon
  appendt een lege string per spec (`SSELineStream.swift:104–106`). Twee
  regression tests: `commentBetweenDataLines` en `bareDataLineWithoutColon`
  (`SSEParserTests.swift:171, 187`).
- Waarom: Cloudflare stuurt `: heartbeat` keep-alives en die mogen geen
  accumulating event verpesten.

**L4 — `HermesError.errorDescription` is nu exhaustive**
- Wat: `HermesError.swift:18–58` heeft een case voor álle errors incl.
  de nieuwe `inStream(String)`. Dutch user-facing strings.
- Waarom: ontbrekende cases vallen anders naar een default fallthrough
  die taalkundig rommelig wordt bij nieuwe errors.

### Pre-existing bug gevonden tijdens H4

Tijdens het schrijven van de streaming happy-path test bleek dat de oude
implementatie `URLSession.bytes.lines` direct aan de SSE parser voedde,
terwijl `AsyncLineSequence` juist de blank-line event separators weggooit.
Gevolg: alle frames werden als één blob gedecodeerd en de test crashte op
"Unexpected character '[' after top-level value". Fix: nieuwe public type
`SSEByteLineSequence` die de raw byte stream zelf splitst met behoud van
lege regels (`SSELineStream.swift:172–231`). `HermesClient.pumpEvents`
gebruikt die nu in plaats van `bytes.lines` (`HermesClient.swift:194`).
Unit tests: `@Suite("SSEByteLineSequence")` in `SSEParserTests.swift:250`
met 5 tests (preserves empty lines, CRLF strip, trailing line EOF, empty
input, multi-byte UTF-8 split). Genoteerd als `99-followups.md` entry #4.

### Cross-boundary patch in ChatModel.swift

`HermesError.inStream(String)` toevoegen brak de `switch` in Task 22's
`ChatModel.swift`. Eén minimale case toegevoegd zodat de build groen is;
de semantiek (treat in-stream error als stream interruptie wanneer er al
partial content is, anders `.other(message)`) volgt exact wat task 22 al
doet voor andere mid-stream fouten. Genoteerd als `99-followups.md`
entry #3 voor task 22 om desgewenst verder te verfijnen.

### Self-review (6 /review categorieën)

1. **Swift 6 strict concurrency** — `HermesClient` is een actor, alle
   mutable state is geïsoleerd; de `pumpEvents` en `drainErrorBody` helpers
   zijn `private static` om geen actor-isolation te hoeven claimen vanuit
   een detached Task; de captured `decoder` wordt als `localDecoder` in de
   Task closure meegegeven; `HermesEndpoint` en `HermesError` zijn
   `Sendable`; `MockURLProtocol` gebruikt `@unchecked Sendable` met
   `nonisolated(unsafe)` static state omdat tests `.serialized` draaien.
2. **SwiftUI quality** — N/A, deze task zit volledig in Core/Networking.
3. **Performance** — SSE byte splitting draait O(n) over de byte stream,
   één buffer per regel met `reserveCapacity`; error body drain is
   gecapped op 4 KB zodat een rogue server geen geheugen eet; decoder
   wordt één keer gebouwd en hergebruikt.
4. **Security** — API key nooit meer loggable via `description`; timeouts
   op 60 seconden; error bodies max 4 KB; geen force unwraps in productie
   (wel één `fatalError` in test helper voor `HTTPURLResponse.init` met
   een uitleg-comment waarom dat nooit faalt).
5. **Architecture** — `HermesError` blijft hét enum voor alle errors uit
   deze laag; de SSE parser types zijn puur generiek over `Base: AsyncSequence`
   en hangen niet van URLSession af; tests injecteren een eigen
   `URLSession` via `URLSessionConfiguration.ephemeral` + `protocolClasses`.
6. **Project-specific standards (CLAUDE.md)** — Dutch user-facing strings
   in `errorDescription`, English doc comments; geen force unwraps in
   productiecode; geen `ObservableObject` (niet relevant hier); files
   onder of gelijk aan 400 regels (`HermesClientTests.swift` is nu 398
   door `MockURLProtocol` te splitten); conventional commit
   `fix(task19): networking robustness`.
