# Agent Guide

Dit document beschrijft exact hoe een Claude Code instance een task uit `docs/TASKS/` uitvoert. Lees dit aan het begin van elke sessie.

## De workflow in één oogopslag

```
1. pick task      → kies de laagste NN uit docs/TASKS/ die nog niet "✅ Done" is
2. read all docs  → ARCHITECTURE.md, API_REFERENCE.md, CLAUDE.md
3. read task      → docs/TASKS/NN-slug.md volledig
4. implement      → schrijf de code, maak de files aan
5. verify         → run wat in de task als verification staat
6. mark done      → update docs/TASKS/NN-slug.md met ✅ Done + summary
7. commit         → conventional commit met taskNN scope
8. stop           → sessie klaar, geen volgende task
```

Eén taak per sessie. Niet doorgaan naar de volgende. Niet refactoren buiten scope.

## Waarom één taak per sessie

- Context blijft fris
- Elke commit is reviewbaar en reversibel
- Als iets fout gaat is de blast radius klein
- Een nieuwe sessie kan verder met volledige context van wat er is gebeurd via git log

## Step 1: Kies de task

```bash
ls docs/TASKS/
```

Sorteer op filename (ze hebben NN-prefix). Open elke `.md` file van laag naar hoog en kijk naar de eerste regel:

- `# Task NN: slug` — niet gestart
- `# Task NN: slug ✅ Done` — klaar, skip
- `# Task NN: slug 🚧 In progress` — iemand anders is bezig, skip (of als dat jij was en je sessie crashte: lees de file en ga verder)
- `# Task NN: slug ❌ Blocked: reason` — geblokkeerd, skip en kies de volgende die geen dependency heeft op deze

Pak de laagste niet-done taak zonder onvervulde dependencies.

## Step 2: Lees alle context

Minstens deze drie files, van kaft tot kaft:

1. `CLAUDE.md` — regels voor hoe je code schrijft en commit
2. `docs/ARCHITECTURE.md` — hoe het systeem in elkaar zit
3. `docs/API_REFERENCE.md` — exact wat de backend levert

Als de taak iets in Networking aanraakt, lees ook `docs/CLOUDFLARE_TUNNEL.md`.

## Step 3: Lees de task file volledig

Elke task file heeft dezelfde structuur:

```markdown
# Task NN: slug

**Status:** Niet gestart
**Dependencies:** (none | Task MM, Task PP)
**Estimated effort:** 15-45 min

## Doel
Eén zin.

## Context
Waarom dit nodig is, wat het in het grotere geheel doet.

## Scope
### In scope
- Bullet 1
- Bullet 2

### Niet in scope
- Dingen die je NIET moet doen
- Zodat je geen scope creep krijgt

## Implementation

### Files to create
- `Sources/HermesMac/Core/Networking/HermesClient.swift`
- `Tests/HermesMacTests/HermesClientTests.swift`

### Files to modify
- `Package.swift` (voeg dependency toe)

### Code

[Volledige of near-volledige code voorbeelden]

## Verification

```
swift test --filter HermesClientTests
# Expected: 3 tests passed
```

En:
```
swift build
# Expected: build succeeds without warnings
```

## Done when

- [ ] File X bestaat en compileert
- [ ] Tests passen
- [ ] Geen nieuwe SwiftLint warnings
- [ ] Commit gemaakt met `feat(taskNN): ...`
```

Lees dit **volledig** voordat je begint. Als iets onduidelijk is, check eerst de ARCHITECTURE en API_REFERENCE. Als het dan nog onduidelijk is, implementeer het deel dat je zeker weet, commit dat, en voeg een `## Open vragen` sectie onderaan de task file toe.

## Step 4: Implementeer

- Open files via Read/Edit (niet via terminal `cat`/`sed`)
- Maak nieuwe files via Write (niet via `echo > file`)
- Check syntax door `swift build` te runnen — foutmeldingen leiden je naar het probleem
- Als je een dependency toevoegt aan `Package.swift`, run direct `swift package resolve` om te checken of het beschikbaar is

### Anti-patterns

- ❌ Een task uitbreiden omdat je "toch wel even" iets anders wil fixen
- ❌ Bestaande code refactoren zonder dat de task het vereist
- ❌ SwiftLint regels uitzetten omdat ze ongemakkelijk zijn
- ❌ `// TODO: later` comments zonder corresponding entry in `99-followups.md`
- ❌ Tests skippen "omdat het maar een klein ding is"
- ❌ Commits met meerdere logische veranderingen

### Patterns we wél willen

- ✅ Kleine functies met duidelijke naamgeving
- ✅ `///` doc comments op alles wat publiek is
- ✅ `@MainActor` waar UI-code draait
- ✅ `actor` voor shared mutable state over threads (netwerk, keychain)
- ✅ Pure `struct` waar mogelijk, geen class overkill
- ✅ Error types per module, conforme `LocalizedError`
- ✅ Swift Testing (`@Test`, `#expect`) voor unit tests

## Step 5: Verifieer

Elke task file heeft een `## Verification` sectie met concrete commands. Run ze. Als ze niet passen, los het op. Commit NIET als een verification faalt zonder het expliciet in de task file te loggen onder "Open vragen" of "Known issues".

## Step 6: Markeer done

Open de task file en:

1. Verander de eerste regel van `# Task NN: slug` naar `# Task NN: slug ✅ Done`
2. Voeg onderaan een sectie toe:

```markdown
## Completion notes

**Date:** YYYY-MM-DD
**Commit:** <sha>

Samenvatting van wat je hebt gedaan, eventuele afwijkingen van de spec, en iets om op te letten voor de volgende task.
```

## Step 7: Commit

```bash
git add <alleen de files die bij deze taak horen>
git commit -m "feat(task03): implement SSE line parser

Specifics if relevant."
```

**Commit message format:**
```
type(taskNN): short imperative line

Optional body with more context, wrapped at ~72 chars.
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

Check dan even met `git status` of er geen andere files per ongeluk zijn meegenomen.

## Step 8: Stop

Laat een korte summary aan de user zien:

```
Task 03 klaar. SSE parser werkt met heartbeat filtering, alle 5 tests passen.
Commit: abc1234
Volgende logische taak: 04-chat-model
```

En hou op. Begin niet aan de volgende.

## Als iets misgaat

### Compilation errors die je niet snapt

Lees de error zorgvuldig, check Swift 6 concurrency documentation voor `@Sendable`, `actor isolation`, `@MainActor`. 90% van de Swift 6 fouten komen door iets wat niet-Sendable is in een Sendable context.

### Tests die niet passen

Debug één test tegelijk. Print statements zijn OK tijdens debugging maar haal ze weg voor commit.

### Task spec lijkt verkeerd

Implementeer wat wél klopt, commit dat, en beschrijf het probleem in `## Open vragen` in de task file. Niet gokken.

### Dependency conflicten

Als `swift package resolve` failt, check de Package.swift van de dependency voor Swift versie eisen. Soms moet je een oudere versie pinnen. Log dit in de task file.

## Een laatste woord

Je bent niet sneller als je taken overslaat of haastig werkt. Langzaam en netjes = snel in de praktijk, want je hoeft niks te undo'en. De user heeft liever 10 goede commits dan 50 halfbakken.

Succes.
