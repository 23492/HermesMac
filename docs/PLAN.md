# PLAN — Implementation roadmap

Dit is de volledige routekaart voor HermesMac v1. Elke task hieronder heeft een corresponding file in `docs/TASKS/NN-slug.md` met de implementatiedetails.

## Filosofie

We bouwen in lagen. Eerst een kale scaffold waar niks stuk kan, dan netwerk, dan UI, dan rijke rendering, dan polish. Elke laag is compleet en gecommit voordat de volgende begint. Elke task is 15-45 minuten werk.

## Milestones

### M1: Foundation (Tasks 00-02) — kale infra
Er is een Swift package die compileert, een placeholder view, en een SSE parser die unit-tested is.

### M2: Networking (Tasks 03-05) — praat met de server
`HermesClient` kan chat completions streamen. Keychain-backed settings. Endpoint selector met race.

### M3: Persistence + basic UI (Tasks 06-09) — MVP chat
SwiftData-backed conversations, een lijst, een chat view, een input composer. Je kan een bericht sturen en een antwoord streamen in plaintext.

### M4: Rich rendering (Tasks 10-12) — het ziet er goed uit
MarkdownUI integratie, code syntax highlighting, message actions (copy, delete).

### M5: Cross-platform polish (Tasks 13-15) — iOS+macOS
NavigationSplitView op macOS, NavigationStack op iOS, platform-specifieke shortcuts, settings scherm.

### M6: Ship (Tasks 16-18) — klaar voor dagelijks gebruik
App icon, launch screen, empty states, error states, "try again" flows, basic analytics (lokaal), release build.

## Volledige task lijst

| Nr | Taak | Dependencies | Milestone |
|----|------|--------------|-----------|
| 00 | Scaffold: Package.swift, basic app, entry point | none | M1 |
| 01 | Theme + cross-platform color helpers | 00 | M1 |
| 02 | SSE line parser (unit tested) | 00 | M1 |
| 03 | HermesClient actor + chat completions | 02 | M2 |
| 04 | AppSettings + KeychainStore | 00 | M2 |
| 05 | EndpointSelector met race logica | 03, 04 | M2 |
| 06 | SwiftData models + ModelStack | 00 | M3 |
| 07 | ConversationRepository (main actor, simple) | 06 | M3 |
| 08 | ChatModel + streaming integratie | 03, 07 | M3 |
| 09 | ChatView + MessageInput + ConversationList | 08 | M3 |
| 10 | MarkdownUI integratie | 09 | M4 |
| 11 | Splash syntax highlighter wrap | 10 | M4 |
| 12 | Message actions (copy, delete, regenerate) | 09 | M4 |
| 13 | macOS NavigationSplitView shell + commands | 09 | M5 |
| 14 | iOS NavigationStack shell + gestures | 09 | M5 |
| 15 | SettingsView (API key, URLs, about) | 04 | M5 |
| 16 | App icon, launch screen, assets | 14 | M6 |
| 17 | Error states + retry UX | 08, 09 | M6 |
| 18 | Release build config + README polish | all | M6 |
| 99 | Followups (lopende backlog, niet sequencially) | - | - |

## Kritische pad

```
00 → 02 → 03 → 08 → 09  (minimaal werkende chat)
     ↓    ↓    ↑
     04 ──┴────┘
```

Tot task 09 heb je niks visueels om te demonstreren. Daarna elke task toegevoegde waarde.

## Hoe we tasks aan Claude Code geven

De workflow is:

1. Hoofd-agent (ik) spawnt een Claude Code instance met een prompt die zegt: "Ga naar /root/HermesMac, lees CLAUDE.md en AGENT_GUIDE.md, pak de laagste niet-done task en voer hem uit."
2. Claude Code werkt de task af, commit, en stopt.
3. Hoofd-agent reviewt de commit (`git log -1`, `git show`), valideert met build/tests, en pakt de volgende.
4. Als iets fout gaat: hoofd-agent opent de task file, voegt een "Known issue" sectie toe, spawnt opnieuw.

Zie `docs/ORCHESTRATION.md` voor de exacte commando's.

## Succes criteria voor v1

De app is v1-ready wanneer alle onderstaande waar zijn:

- [ ] Build zonder warnings op macOS en iOS onder Swift 6 strict concurrency
- [ ] Je kan een API key invoeren en opslaan in Keychain
- [ ] Je kan een nieuwe conversation maken
- [ ] Je kan een bericht sturen en een streaming antwoord zien
- [ ] Markdown wordt correct gerenderd inclusief code blocks met syntax highlighting
- [ ] Conversation history persisteert over app restarts
- [ ] Je kan een conversation deleten en een message copyen
- [ ] Local endpoint race werkt (als je beide configureert)
- [ ] Via Cloudflare tunnel bereikbaar onderweg
- [ ] Geen crashes in 10 minuten typisch gebruik
- [ ] Minimal test coverage (SSE parser + ChatModel state transitions)

Geen app store submission, geen App Review voorbereiding, geen certificate provisioning. Dat is een aparte v1.1 task als en wanneer Kiran dat wil.
