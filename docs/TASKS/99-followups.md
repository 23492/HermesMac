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

## 7. [2026-04-11 task-24] Theme.userBubbleText contrast-aware op non-blue accents

Task 24 code review: `Theme.userBubbleText` is hard-coded op `.white` wat alleen
klopt bij een blauw-ish accent color. Bij een lichte accent (gele/cyaan custom
accent in Settings > Accentkleur) wordt witte tekst op een lichte achtergrond
onleesbaar. Zie `Sources/HermesMac/DesignSystem/Theme.swift:102`.

Voorstel: gebruik een contrast-aware computed die de luminantie van
`Color.accentColor` bekijkt en `.white` / `.black` teruggeeft. Overweeg
`Color(NSColor(name: nil, dynamicProvider: { appearance in ... }))` voor
appearance-aware tokens of een dedicated `PlatformColor`-brug. Vereist een
design pass — niet alleen code — omdat ook de hover/press states en eventuele
borders mee moeten.

Status: open

---

## 8. [2026-04-11 task-24] Verplaats CodeBlockView van Features/Chat/ naar DesignSystem/

Task 24 code review: `MarkdownTheme.hermes` (`DesignSystem/MarkdownTheme.swift`)
refereert `CodeBlockView`, maar `CodeBlockView` woont in
`Sources/HermesMac/Features/Chat/CodeBlockView.swift`. Dat is een
cross-layer dependency — de DesignSystem-laag hoort niks uit Features/ te
importeren. Technisch werkt het omdat ze in dezelfde module zitten, maar het
breekt de architectuur-intentie uit `docs/ARCHITECTURE.md` dat DesignSystem
de onderste laag is.

Voorstel: verhuis `CodeBlockView.swift` + `CodeBlockStyle` (en de
`PlatformColor`-bridge extension) naar `Sources/HermesMac/DesignSystem/`.
Update de imports en alle call sites. Het is een pure verplaatsing zonder
gedragschange. Raakt 1 file in Features en voegt 1 file toe in DesignSystem.
Past niet in Task 24 omdat de taak expliciet `Features/Chat/*` buiten scope
zet.

Status: open
