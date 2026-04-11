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

Status: done (afgesloten door task 19 H3 — `HermesClient.streamChatCompletion`
drained nu tot 4 KB van error bodies en de gedeelde `httpStatus` pad werkt
voor zowel listModels als streaming; zie branch `fix/task19-networking`
commit `816c5ad`)

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

Status: open

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
