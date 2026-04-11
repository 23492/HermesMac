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

## 3. [2026-04-11 task-21] HermesClientTests "listModels decodes a valid response" crashet met signal 11

Tijdens task 21 (`swift test` run) opgemerkt: de `HermesClient` suite heeft
een test `listModels decodes a valid response` (`HermesClientTests.swift:?`)
die nu met een uncaught Foundation exception eindigt (libc++abi terminating
due to uncaught NSException, stack wijst naar `$sSD8_VariantV8setValue_...`
in `listModelsSuccess` test). Uncaught exception wordt in `NSDictionary`
stored in een Swift `Dictionary`. Waarschijnlijk is dit een testing helper
die een `NSDictionary` niet-Sendable waarde in een JSON fixture stopt en
sindsdien niet is bijgewerkt voor Swift 6 bridging.

`HermesClient` zelf is buiten Task 21 scope. Deze is óf dezelfde root cause
als followup #2, óf een aparte test fixture-issue. Toevoegen aan task 22
(HermesClient review) als die niet al een item hiervoor heeft.

Status: open

---

## 4. [2026-04-11 task-21] `KeychainError.description` en `lastKeychainError` zijn Engelstalig

`KeychainStore.KeychainError.description` gebruikt een Engelse prefix plus
`SecCopyErrorMessageString(...)` (die wél locale-aware is). Voor developer-
facing logs is dat prima, maar zodra Task 23 `AppSettings.lastKeychainError`
in `SettingsView` toont moet die view mappen naar Nederlandse meldingen
(bv. `case .missingEntitlement → "Keychain-toegang ontbreekt..."`). Niet
fixen in `KeychainStore` zelf — de struct is een laag onder de UI en hoort
locale-neutraal te blijven.

Actie voor Task 23: bouw een `KeychainError → String` presenter in
`SettingsView` die per case een Nederlandse string levert, in plaats van
de `description` rechtstreeks in een `Text(...)` te tonen.

Status: open
