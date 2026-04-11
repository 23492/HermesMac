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

## 3. [2026-04-11 task-20] Mid-stream save strategy (persistence H2)

Uit de code review van 2026-04-11: `ChatModel.performStreaming` muteert
`assistantMessage.content` bij elke chunk binnen een streaming loop, maar
`ConversationRepository.touch(conversation)` wordt pas aan het einde
geroepen. Als de app midden in een stream crasht of geforceerd wordt
afgesloten is de partiële inhoud niet gegarandeerd in de store geland.
Raakt `ChatModel.swift` (Task 22 terrein) dus uit scope voor task 20.

Voorstel: binnen `performStreaming` elke N chunks (of elke 500 ms)
`try? repository.touch(conversation)` of een explicit flush roepen —
de bestaande `touch(_:)` noemt `context.save()` al. Alternatief: debounce
een save op basis van `assistantMessage.content.count` delta. Overleg
met Task 22 agent bij merge.

Status: open

---

## 4. [2026-04-11 task-20] Empty-conversation pruning (persistence M2)

Uit de code review: als de user `Cmd+N` (of iOS: "Nieuwe chat") indrukt,
terug navigeert zonder iets te typen en daarna opnieuw `Cmd+N` doet,
ontstaan er meerdere lege conversations in de sidebar. Het is een
product-beslissing of we die auto-pruneren of gewoon laten staan en
op het Trash laten drukken door de user.

Voorstel: nieuwe task of productdiscussie. Mogelijke oplossingen:
- `ConversationRepository.create(model:)` kijkt eerst of er een lege
  conversation bestaat en hergebruikt die.
- Background job op app-start dat conversations zonder messages ouder
  dan N minuten verwijdert.
- Niets doen en het aan de user overlaten.

Status: open

---

## 5. [2026-04-11 task-20] Schema versioning voor SwiftData (persistence M3)

Uit de code review: pre-release is het nog niet kritiek, maar zodra we
TestFlight gaan doen moet `ModelStack.shared` een `Schema` hebben met
een `VersionedSchema` stack en een `MigrationPlan`. Anders is elke
model wijziging een data wipe.

Voorstel: aparte task `25-swiftdata-versioning.md`. Vóór de eerste
TestFlight build. Voorbeeldstructuur:

```swift
enum HermesSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ConversationEntity.self, MessageEntity.self]
    }
}
```

Plus een `MigrationPlan` met `stages: [.lightweight(fromVersion:toVersion:)]`.

Status: open

---

## 6. [2026-04-11 task-20] Prefetch messages relationship (persistence M4)

Uit de code review: `ConversationRepository.listAll()` geeft alleen
conversations terug; de sidebar toont geen message preview in v1 dus
dit is pas relevant zodra dat wél gebeurt. Op dat moment wordt elke
`conversation.messages.last` access een aparte fault, wat op lange
lijsten N+1 queries wordt.

Voorstel: wanneer we een preview toevoegen, `FetchDescriptor` uitrusten
met `relationshipKeyPathsForPrefetching: [\.messages]` in `listAll()`.
Voor v1 is dit niet nodig.

Status: open

---

## 7. [2026-04-11 task-20] ModelStack fatalError logging (persistence L4)

Uit de code review: `ModelStack.shared` doet `fatalError("Failed to create
ModelContainer: \(error)")` zonder os.Logger fault log vooraf. Kan niet
onder task 20 gefixt worden omdat `ModelStack.swift` door Task 23
(app-shell) gewijzigd wordt — die fix bundelt logging met een
`Result<..., Error>` wrap + error recovery UI in `LaunchView`. Zit
expliciet in `docs/TASKS/23-app-shell.md` onder H2 + "Persistence L4".

Status: open (wacht op Task 23)

---

## 8. [2026-04-11 task-20] MessageEntity.role storage-type promotie (persistence L3 partial)

Uit de code review: de review vraagt `MessageEntity.role` te promoten
van `String` naar `MessageRole` enum. Task 20 heeft de enum zelf
toegevoegd (`Sources/HermesMac/Core/Persistence/MessageEntity.swift`)
plus een typed convenience overload op
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
de stored property op `MessageEntity` promoten naar `MessageRole`. Pre
release dus geen migratie nodig, wel een paar mechanical edits.

Status: open (wacht op merge task 22 + 20)
