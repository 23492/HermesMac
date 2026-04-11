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

Status: open

---

## 3. [2026-04-11 task-23] Theme comment cleanup (L-Theme)

Code review noemde als Low finding dat `DesignSystem/Theme.swift` een
misleidende comment heeft over hoe kleuren uit de asset catalog komen.
Deze file zit buiten de ownership van task 23 (`Features/...`, `App/...`,
`Core/Persistence/ModelStack.swift`) en valt in de scope van task 24.

Voorstel: comment bijwerken zodat hij exact beschrijft welke assets uit de
asset catalog worden gelezen en in welke volgorde ze fallback bieden.
Geen gedragsverandering.

Status: open — ingepland voor task 24
