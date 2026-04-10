# Orchestration — Hoe de hoofd-agent Claude Code aanstuurt

Dit document legt uit hoe de Hermes hoofd-agent (Kiran's primary assistant) Claude Code instances inzet om taken uit deze repo uit te voeren. Als je zelf een Claude Code instance bent: je hoeft dit niet te lezen. Het is voor de orchestrator.

## Voorwaarden

- `claude` CLI is geïnstalleerd (v2.x). Check met `claude --version`.
- `claude auth status` geeft een actief account.
- Repo staat lokaal gecloned op de server waar de orchestrator draait.
- `gh` CLI is geauthenticeerd (voor pushing na commits).

## De basis kick-off

```bash
cd /root/HermesMac
claude -p "$(cat <<'PROMPT'
Je bent een Claude Code instance die aan HermesMac werkt.

1. Lees eerst /root/HermesMac/CLAUDE.md volledig
2. Lees /root/HermesMac/docs/AGENT_GUIDE.md volledig
3. Lees /root/HermesMac/docs/ARCHITECTURE.md volledig
4. Lees /root/HermesMac/docs/API_REFERENCE.md volledig
5. Kies de laagste NN-genummerde task in /root/HermesMac/docs/TASKS/ die NIET met "✅ Done" is gemarkeerd
6. Voer die task uit volgens de instructies in die file
7. Commit wanneer klaar volgens het conventional commit format
8. Stop. Begin niet aan de volgende task.

Antwoord alleen met een korte samenvatting aan het einde: welke task je hebt afgerond, de commit SHA, en of er open vragen zijn.
PROMPT
)" \
  --allowedTools 'Read,Edit,Write,Bash,WebFetch' \
  --max-turns 40 \
  --permission-mode acceptEdits
```

Rationale achter de flags:

- `-p` (print mode): één-shot, geen interactieve TUI, werkt cleaner vanuit de orchestrator
- `--allowedTools 'Read,Edit,Write,Bash,WebFetch'`: alles wat code schrijven nodig heeft. Geen network shenanigans.
- `--max-turns 40`: genoeg voor een 30-minuten task met tests en iteraties. Verhogen naar 60 als blijkt dat taken complexer zijn.
- `--permission-mode acceptEdits`: auto-accept file edits. We hebben het via CLAUDE.md al verboden om buiten scope te werken. Review komt van de orchestrator via git diff.

## Na de run

```bash
cd /root/HermesMac
git log -1 --oneline
git show --stat HEAD
```

Controleer:

1. Is er een nieuwe commit?
2. Klopt het commit message format (`type(taskNN): ...`)?
3. Zijn alleen files gewijzigd die bij de taak horen?
4. Is de corresponderende task file geüpdatet naar `✅ Done`?

Als alles klopt:

```bash
git push origin main
```

Als er iets niet klopt:

- Kleine fix: edit direct en amend de commit
- Grote fix: `git reset HEAD~1`, schrijf wat mis ging naar de task file als "Known issue", kick opnieuw

## Bouwen en testen na elke task

```bash
cd /root/HermesMac

# Build macOS
swift build 2>&1 | tail -20

# Tests
swift test 2>&1 | tail -20
```

We draaien dit vanaf de Linux server (waar de orchestrator zit). `swift build` werkt op Linux voor de meeste dingen, maar SwiftUI-specifieke code compileert daar niet. Dan is de verificatie dat:

- `swift package resolve` werkt
- Core modules (Networking, Persistence) compileren in isolation als library target
- Unit tests van non-UI code passen

Voor volledige compile- en run-tests heb je een Mac nodig. Die stap doet Kiran handmatig of via een Mac runner in GitHub Actions (zie `docs/TASKS/18-release-build.md`).

## Parallelisme

**Niet doen voor v1.** Taken hebben dependencies. De task lijst is sequentieel. Pas als we een fase bereiken waar meerdere onafhankelijke tracks parallel kunnen (bv. task 13 macOS shell en task 14 iOS shell tegelijk), kunnen we twee instances spawnen via `delegate_task` met `tasks:[...]`.

## Failure recovery

### Claude Code sessie hangt of loopt vast

De orchestrator heeft een hard timeout van 40 turns. Als het daarvoor al duidelijk hangt:

```bash
# PID van de claude process
ps aux | grep claude

# Kill
pkill -f 'claude -p'
```

Dan: lees de task file, kijk of er deels werk is gedaan dat het waard is te bewaren, anders `git status` + `git checkout .` om schoon te beginnen.

### Claude Code maakt iets fout

Gewoon reverten en opnieuw:

```bash
git reset --hard HEAD~1
```

Update de task file met een `## Known issues` note waar je specifiek vraagt om dat probleem niet te herhalen.

### Claude Code is klaar maar de code bouwt niet

Lees de fouten. Als het triviaal is, fix direct en amend. Als het niet-triviaal is, revert de commit en voeg een "Known issue" toe aan de task file met de exacte error message. Kick opnieuw.

## Model keuze

Voor simpele tasks (scaffold, theme, glue code): `claude --model sonnet` is voldoende.  
Voor complexe tasks (SSE parser, ChatModel state management, SwiftData edge cases): `claude --model opus`.

De orchestrator kan kiezen per task via de `--model` flag. Default op sonnet, upgrade naar opus als een task meer dan 5 regels aan state management of concurrency bevat.

## Een voorbeeld volledige run cycle

```bash
#!/bin/bash
set -e

cd /root/HermesMac

# Pre-flight check
git status --porcelain
if [ -n "$(git status --porcelain)" ]; then
  echo "Working directory niet schoon, eerst committen of resetten"
  exit 1
fi

# Pick latest sha voor de reset safety
PREV_SHA=$(git rev-parse HEAD)

# Run Claude Code
claude -p "[prompt zoals boven]" \
  --allowedTools 'Read,Edit,Write,Bash' \
  --max-turns 40 \
  --permission-mode acceptEdits

# Review
echo "--- Diff ---"
git diff $PREV_SHA..HEAD --stat
echo "--- Commit message ---"
git log -1 --format=%B

# Build check
swift build 2>&1 | tail -10

# Push
git push origin main

echo "Klaar. Volgende task kan."
```

Dit kan je in een loop zetten maar doe het liever niet blind. Review elke stap.
