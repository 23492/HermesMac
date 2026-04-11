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

## 3. [2026-04-11 task-22] HermesClient.setEndpoint race condition

Uit de code review voor task 22 (H4): `ChatModel.performStreaming` roept bij
iedere request `await client.setEndpoint(endpoint)` aan op de gedeelde
`HermesClient`-actor. Het werkt nu omdat alle chats via dezelfde `ChatModel`
gaan en de actor calls serialiseren, maar zodra er meerdere parallelle
streams of meerdere conversaties met verschillende backends ontstaan wordt
dit een race: de ene stream kan de endpoint van de andere omzetten terwijl
`streamChatCompletion` al loopt.

Voorstel: refactor `HermesClient` zodat `streamChatCompletion(request:)`
een expliciete `endpoint:` parameter (of een frisse ad-hoc client) neemt
in plaats van te leunen op gedeelde actor-state. Dit zit in `HermesClient`
zelf, niet in Chat-feature code, en is out-of-scope voor task 22 (ownership).

Status: open

---

## 4. [2026-04-11 task-22] UI strings consolideren naar Localizable.strings

Uit de code review voor task 22 (L2): de foutbanners, empty states en
composer-labels in de Chat feature (`ChatView.swift`, `MessageBubbleView.swift`,
`MessageComposerView.swift`, `ChatError.swift`) bevatten hard-coded Nederlandse
strings. Werkt prima voor v1, maar zodra we een tweede taal willen
ondersteunen moeten deze naar `Localizable.strings` / `String(localized:)`
zodat Xcode ze automatisch extraheert.

Voorstel: als aparte i18n-task alle user-facing Nederlandse strings in de
`Features/`-tree omzetten naar `String(localized:)` met bijpassende
`Localizable.strings`. Niet in scope voor een bug-fix-task omdat dit
breed treft en een consistente aanpak vraagt.

Status: open

---

## 5. [2026-04-11 task-22] CodeBlockView trimt trailing newline ook bij Text

Uit de code review voor task 22 (L4): `CodeBlockView.trimmedContent`
strip alle trailing newlines zodat de fenced-code-block render geen lege
slotregel laat zien. Dat is voor de zichtbare render prima, maar de *copy*-
knop kopieert nu ook de getrimde string; als de oorspronkelijke codeblock
in het antwoord bewust op een newline eindigde (bv. een compleet Python-
bestand) komt die newline niet mee in de clipboard-paste.

Voorstel: splits `trimmedContent` in `displayContent` (voor de Text-render)
en `copyContent` (originele string inclusief trailing newline) zodat copy
de bron-vorm behoudt. Low priority — bijna geen user merkt dit op.

Status: open
