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

## 3. [2026-04-11 task-19] Cross-boundary `ChatModel.swift` fix voor nieuwe `HermesError.inStream` case

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

## 4. [2026-04-11 task-19] Pre-existing bug: `URLSession.bytes.lines` slikt blank-line SSE delimiters

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
