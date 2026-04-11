# Task 99: Followups

**Status:** Lopend
**Dependencies:** N/A

Dit is een lopende lijst van dingen die tijdens implementatie bovenkomen maar buiten scope vallen van de huidige task. Agents die iets opmerken dat fixed moet worden maar niet nu: voeg een entry toe.

Format per entry:

```
## NN. [YYYY-MM-DD task-XX] Korte titel

Uit welke task dit komt, wat het probleem is, en een voorstel voor de fix.

Status: open | in progress | done
```

---

## 1. [placeholder] Dit is een voorbeeld

Dit komt uit nergens. Het dient om te laten zien hoe entries eruit zien.

Status: done (voorbeeld)

---

<!-- Nieuwe entries hieronder. Hou nummering doorlopend. -->

## 2. [2026-04-10 task-03] HermesClientTests "listModels maps 401" faalt

Tijdens task 10 verificatie opgemerkt: `HermesClientTests.httpError` verwacht
dat een gestubde 401 response een `HermesError.httpStatus(401, _)` veroorzaakt,
maar de client geeft geen error — `Issue.record("Expected error")` wordt
geraakt (`HermesClientTests.swift:53`). De andere `HermesClient` tests slagen
wel, dus `MockURLProtocol` wordt op zich geladen. Waarschijnlijk komt het
doordat `HermesClient.listModels` bij een non-2xx response nog geen error
gooit; de gestubde body wordt gewoon teruggegeven en decodering slaagt op
iets leegs, of de status check zit op de verkeerde plek.

Voorstel: in `HermesClient.listModels` expliciet de `HTTPURLResponse.statusCode`
controleren en bij non-2xx `HermesError.httpStatus(code, body)` gooien voordat
er gedecodeerd wordt. Waarschijnlijk dezelfde check die al in de streaming
chat path zit missen hier.

Status: done — afgesloten door task 19 (fix/task19-networking). `HermesClient.listModels`
roept nu `validate(response:body:)` aan vóór decodering (`HermesClient.swift:81`),
en de streaming path drained de error body via `drainErrorBody` (`HermesClient.swift:141`).
De regression test `httpError401` (`HermesClientTests.swift:52`) én de nieuwe
`streaming401` (`HermesClientTests.swift:290`) lopen beide groen.

---

## 3. [2026-04-11 task-20] H2 mid-stream save strategy

Uit code review 2026-04-11 (Persistence review H2). `ChatModel.swift`
slaat partial assistant content pas op na de stream, waardoor een crash
midden in een reply al het tot-dan-toe gestreamde verliest. Raakt
`Features/Chat/ChatModel.swift` — viel buiten Task 20's ownership.

Voorstel: debounce een `context.save()` elke N chunks of elke T ms in
de stream loop; rollback bij error. Combineert goed met task 22's
`syncMessages()` helper die al per chunk aangeroepen wordt.

Status: open

---

## 4. [2026-04-11 task-20] M3 SwiftData schema versioning voor TestFlight

Uit code review 2026-04-11 (Persistence review M3). Geen migratie
strategy voor `ConversationEntity` / `MessageEntity`. Niet urgent zolang
we pre-TestFlight zijn (schema kan vrij veranderen), maar voor de
eerste externe build moet er een `Schema`/`SchemaMigrationPlan` staan
met explicit versies.

Status: open (doen vóór eerste TestFlight build)

---

## 5. [2026-04-11 task-20] M2 empty "Nieuwe chat" pruning beleid

Uit code review 2026-04-11 (Persistence review M2). Lege conversations
stapelen zich op in de sidebar als de user meerdere keren op "Nieuwe
chat" drukt zonder iets te typen. Moet een product beslissing worden:
alleen opslaan op eerste user message? prunen bij app start? verbergen
tot er tenminste één message is?

Status: open (product decision)

---

## 6. [2026-04-11 task-20] M4 Prefetch `messages` relationship in `listAll()`

Uit code review 2026-04-11 (Persistence review M4). Lazy loading van
`conversation.messages` is op dit moment prima omdat de sidebar alleen
`title` en `updatedAt` leest. Zodra de sidebar message-preview gaat
tonen (laatste assistant reply), wordt dit een N+1 query.

Voorstel: `FetchDescriptor` met `relationshipKeyPathsForPrefetching =
[\.messages]` toevoegen op dat moment.

Status: open (pas nodig wanneer sidebar message preview toont)

---

## 7. [2026-04-11 task-22] H4 `HermesClient` per-call endpoint refactor

Uit code review 2026-04-11 (Chat review H4). `HermesClient` houdt
endpoint als instance property + mutator, wat theoretisch een race is
als twee calls tegelijk de endpoint wisselen. De juiste fix is een
pure refactor waarbij `streamChatCompletion` en `listModels` een
`HermesEndpoint` parameter accepteren. Raakt Networking API → Task 19
territory als pure architecture cleanup.

Voorstel: signature wordt `streamChatCompletion(messages:model:on:
endpoint:)`. Task 22 sluit na merge van Task 19.

Status: open

---

## 8. [2026-04-11 task-22] L2 UI string i18n consolidation

Uit code review 2026-04-11 (Chat review L2). User-facing strings staan
verspreid over `ChatView`, `RootView`, `SettingsView`, `ChatError` als
string literals. Voor toekomstige lokalisatie moet dit naar
`Localizable.xcstrings` (String Catalogs) zodat `String(localized:)`
een key-lookup wordt.

Voorstel: in een eigen task (niet deel van review cleanup) alle
literals verhuizen naar een String Catalog per feature module.

Status: open (eigen task, lage urgentie)

---

## 9. [2026-04-11 task-24] Theme.userBubbleText contrast-aware accent

Uit code review 2026-04-11 (Design review, deferred). `Theme.userBubbleText`
is hardcoded `.white` terwijl de bubble background `.accentColor` is —
breekt zodra de user een lichte accent kiest (yellow, mint). Moet een
contrast-aware variant worden die luminance berekent en zwart/wit
picked.

Voorstel: `Color.contrasting(with: background)` helper, inclusief
design review van het resultaat op alle macOS accent kleuren. Deze
heeft een design pass nodig en is niet puur een code fix.

Status: open

---

## 10. [2026-04-11 task-24] Move `CodeBlockView` from `Features/Chat/` to `DesignSystem/`

Uit code review 2026-04-11 (Design review, deferred). `CodeBlockView`
gebruikt enkel `CodeHighlighter` en `Theme` en hoort daarom in
`DesignSystem/`. Is geen chat-specifiek component. Verplaatsing is
puur architectureel maar raakt tegelijk `Features/Chat/*.swift`
imports en `MessageBubbleView` caller — buiten Task 24's ownership.

Voorstel: `git mv` + import updates in een eigen refactor task
zodra alle parallelle cleanup branches gemerged zijn.

Status: done — afgesloten door task 27 (fix/task27-codeblock-move). `git mv` naar
`Sources/HermesMac/DesignSystem/CodeBlockView.swift`. Geen import wijzigingen nodig
(zelfde module). MarkdownTheme.swift compileert ongewijzigd.

---

## 11. [2026-04-11 meta] Update `ORCHESTRATION.md` to document parallel cleanup pattern

Uit plan 2026-04-11 (parallel remediation van review findings). De
6-agent parallel run voor tasks 19–24 was succesvol maar
`docs/ORCHESTRATION.md` zegt nog steeds "Parallelisme — Niet doen voor
v1" op regel 91. Die regel klopte voor v1 omdat tasks sequentiële
dependencies hadden, maar post-v1.0.0 cleanup past prima bij het
disjoint-files-criterium uit hetzelfde document.

Voorstel: `ORCHESTRATION.md` regel 91 aanpassen, de 6-agent run
referen als voorbeeld, criteria documenteren voor wanneer
parallellisme veilig is (zero file overlap + geen API dependency tussen
tasks).

Status: open

---

## 12. [2026-04-11 task-19] Cross-boundary `ChatModel.swift` fix voor nieuwe `HermesError.inStream` case

Task 19 voegt `HermesError.inStream(String)` toe (H1 + L4). De bestaande
`switch` in `ChatModel.swift` (eigendom van task 22) was niet exhaustive en
weigerde daarom te compileren. Zonder een minimale patch daar kan task 19
überhaupt niet groen builden, dus is één nieuwe case toegevoegd in
`ChatModel.swift` (zie `ChatModel.swift:~/handleError`) die de in-stream
error op dezelfde manier afhandelt als een stream interruptie zodra er al
partial content is, en anders als `.other(message)` surface't. Dat valt
qua UX precies in wat task 22 al doet voor andere mid-stream fouten.

Follow-up voor task 22: als de chat UX voor in-stream errors verfijnder moet
worden (bv. een aparte banner of label dat het over een server-side error
gaat in plaats van een netwerk drop), pak die hier op. De huidige mapping
is een veilige default, geen permanent ontwerp.

Status: open (task 22 verantwoordelijkheid)

---

## 13. [2026-04-11 task-19] Pre-existing bug: `URLSession.bytes.lines` slikt blank-line SSE delimiters

Tijdens het schrijven van de streaming tests (H4) kwam een niet eerder
opgemerkte bug naar boven in de oude `HermesClient.streamChatCompletion`
implementatie: de code voedde `bytes.lines` (a.k.a. `AsyncLineSequence`)
direct aan de SSE parser, maar `AsyncLineSequence` **collapseert**
opeenvolgende newlines en verwijdert zo precies de lege regels die SSE als
event separator gebruikt. Gevolg: een real-backend stream met meerdere
frames zou door de parser lopen tot `\n\n` EOF, waarna alle frames als één
blok gedecodeerd zouden worden — en vervolgens crashen met "Unexpected
character '[' after top-level value". Dat dit in productie nooit zichtbaar
werd komt omdat task 10 géén streaming integration test had (vandaar H4).

Fix zit in task 19: nieuwe type `SSEByteLineSequence` (`SSELineStream.swift:172`)
split de raw byte stream zelf op `\n` en *behoudt* lege regels. `HermesClient`
voedt die nu aan `SSELineStream` in plaats van `bytes.lines`
(`HermesClient.swift:194`). Unit tests voor de byte splitter staan in
`SSEParserTests.swift` onder `@Suite("SSEByteLineSequence")`.

Status: done — gefixt in task 19

---

## 14. [2026-04-11 task-20] `MessageEntity.role` storage-type promotie naar enum

Uit code review 2026-04-11 (Persistence L3). Task 20 heeft de `MessageRole`
enum toegevoegd plus een typed convenience overload op
`ConversationRepository.appendMessage` én een typed `init` op
`MessageEntity`, maar de opgeslagen property blijft voorlopig `String`
omdat een volledige promotie cascadeert in files buiten task 20's
ownership (`Features/Chat/ChatModel.swift` + `ChatView.swift` +
`MessageBubbleView.swift` doen string-compares `message.role ==
"assistant"`, en `Tests/HermesMacTests/ChatModelTests.swift` +
`ModelStackTests.swift` initialiseren met raw strings).

Voorstel: na de merge van tasks 20 en 22, in een volgende followup-task
de Features/Chat vergelijkingen omzetten naar `message.roleEnum == .user`
etc., de `appendMessage` call sites naar de typed overload, en dan pas
de stored property op `MessageEntity` promoten naar `MessageRole`.
Pre-release dus geen migratie nodig, wel een paar mechanical edits.

Status: open (wacht op merge task 22 + 20)

---

## 15. [2026-04-11 task-21] `HermesClientTests "listModels decodes a valid response"` crashet met signal 11

Tijdens task 21 `swift test` run opgemerkt: een `HermesClient` test eindigt
met uncaught Foundation exception (libc++abi terminating due to uncaught
NSException). Stack wijst naar `$sSD8_VariantV8setValue_...` — een
`NSDictionary` niet-Sendable waarde in een Swift `Dictionary`. Waarschijnlijk
een testing helper die een `NSDictionary` fixture gebruikt die niet is
bijgewerkt voor Swift 6 bridging.

Mogelijk dezelfde root cause als followup #2, of aparte test fixture issue.
Verifieer na Task 19 merge of dit nog optreedt; zo ja, debug in een aparte
task.

Status: open

---

## 16. [2026-04-11 task-21] `KeychainError.description` en `lastKeychainError` zijn Engelstalig

`KeychainStore.KeychainError.description` gebruikt een Engelse prefix plus
`SecCopyErrorMessageString(...)` (die wél locale-aware is). Voor developer-
facing logs is dat prima, maar zodra `SettingsView` `AppSettings.lastKeychainError`
aan de user toont moet die view mappen naar Nederlandse meldingen
(bv. `case .missingEntitlement → "Keychain-toegang ontbreekt..."`). Niet
fixen in `KeychainStore` zelf — de struct is een laag onder de UI en hoort
locale-neutraal te blijven.

Voorstel: bouw een `KeychainError → String` presenter in `SettingsView`
die per case een Nederlandse string levert, in plaats van de `description`
rechtstreeks in een `Text(...)` te tonen.

Status: open

---

## 17. [2026-04-11 task-22] `CodeBlockView` trimt trailing newline ook bij Copy

Uit code review 2026-04-11 (Chat review L4). `CodeBlockView.trimmedContent`
strip alle trailing newlines zodat de fenced-code-block render geen lege
slotregel laat zien. Dat is voor de zichtbare render prima, maar de *copy*-
knop kopieert nu ook de getrimde string; als de oorspronkelijke codeblock
in het antwoord bewust op een newline eindigde (bv. een compleet Python-
bestand) komt die newline niet mee in de clipboard-paste.

Voorstel: splits `trimmedContent` in `displayContent` (voor de Text-render)
en `copyContent` (originele string inclusief trailing newline) zodat copy
de bron-vorm behoudt. Low priority — bijna geen user merkt dit op.

Status: done — afgesloten door task 27 (fix/task27-codeblock-move). `trimmedContent`
gesplitst in `displayContent` (render, trimt trailing newlines) en `copyContent`
(originele `configuration.content` voor clipboard). Copy button gebruikt nu `copyContent`.

---

## 18. [2026-04-11 task-23] Theme.swift misleidende asset catalog comment

Uit code review 2026-04-11 (Low finding, L-Theme). `DesignSystem/Theme.swift`
heeft een comment die misleidend beschrijft hoe kleuren uit de asset catalog
komen. Task 24 heeft de Nederlandse doc comments al vertaald naar Engels,
maar de specifieke asset catalog comment is niet expliciet geverifieerd.

Voorstel: comment bijwerken zodat hij exact beschrijft welke assets uit de
asset catalog worden gelezen en in welke volgorde ze fallback bieden. Geen
gedragsverandering. Eventueel meteen nakijken tijdens de ORCHESTRATION.md
update (#11).

Status: open

---
