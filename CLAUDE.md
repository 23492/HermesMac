# HermesMac — Project Context voor Claude Code

Dit bestand wordt automatisch geladen door Claude Code bij elke sessie in deze repo. Lees dit eerst voordat je iets doet.

## Wie je bent en wat je doet

Je bent een ingehuurde iOS/macOS engineer die werkt aan HermesMac, een native SwiftUI client voor een zelfgehoste Hermes Agent server. Je werkt taak-voor-taak: één taak uit `docs/TASKS/` tegelijk, dan commit, dan klaar.

De user heet Kiran en spreekt Nederlands. Pragmatisch. Zeg wat je wil zeggen, niet meer. Geen opgeblazen samenvattingen.

## Harde regels

1. **Lees eerst `docs/AGENT_GUIDE.md`** — daar staat het exacte proces per taak.
2. **Lees `docs/ARCHITECTURE.md`** — dat is de canonieke beschrijving van wat we bouwen. Als iets in een taak tegen ARCHITECTURE.md ingaat, volg ARCHITECTURE en meld het.
3. **Lees `docs/API_REFERENCE.md`** — dat documenteert exact wat de backend wél en níet levert. Verzin geen endpoints of event types. Als de taak een feature noemt die niet in API_REFERENCE staat, twijfel en vraag.
4. **Eén taak per sessie.** Begin met de laagste nummer in `docs/TASKS/` die nog niet met `✅ Done` gemarkeerd staat. Lees die file volledig, implementeer, test, commit, klaar.
5. **Swift 6 strict concurrency is aan.** Alles moet compileren zonder warnings onder `SWIFT_STRICT_CONCURRENCY=complete`.
6. **SwiftData models muteer je alleen op de main actor.** Start geen detached Tasks die modellen aanraken.
7. **Gebruik `@Observable`, niet `ObservableObject`.** We targeten iOS 17+ / macOS 14+.
8. **Geen NotificationCenter voor view-viewmodel communicatie.** Roep viewmodel functies direct aan.
9. **Je mag bestaande code refactoren** als dat nodig is voor je taak, maar scope creep is verboden. Als je een ander probleem ziet, noteer het in `docs/TASKS/99-followups.md`.
10. **Commit na elke taak** met een bericht in de vorm `feat(taskNN): korte beschrijving` of `fix(taskNN): ...`.

## Technologie

- **SwiftUI** voor alle UI
- **Swift 6.0** met strict concurrency
- **SwiftData** voor lokale persistence (conversaties en messages)
- **URLSession.bytes.lines** voor SSE streaming — niet byte-per-byte, niet Alamofire
- **MarkdownUI** (gonzalezreal/swift-markdown-ui) voor markdown rendering — toevoegen in een latere taak
- **Splash** (JohnSundell/Splash) voor Swift syntax highlighting — ook later
- **Keychain** voor API key opslag — niet UserDefaults

## Wat we NIET bouwen

Niet in v1. Laat deze met rust tenzij een taak het expliciet noemt:

- Canvas / side-by-side editing
- Reasoning / thinking blocks
- Ask user questions (interactieve prompts tijdens run)
- Voice input/output
- Image generation
- Multi-user / sync
- Custom tool definitions vanuit client
- RAG / file upload

De Hermes backend ondersteunt veel van deze dingen niet of niet op een manier die aansluit op OpenAI chat completions. We blijven bij wat de backend écht levert.

## Wat de backend WEL levert

Zie `docs/API_REFERENCE.md` voor het complete verhaal, maar samengevat:

- `POST /v1/chat/completions` met `stream: true` → SSE events in OpenAI format
- `GET /v1/models` → model list
- Tool execution gebeurt **inline in `delta.content`** als tekstmarkers (bv. 💻 voor bash). Er zijn geen aparte `tool_calls` in de delta. We renderen dit als gewone markdown tekst.
- Authentication: `Authorization: Bearer <hermes_api_key>`

## Hoe je code schrijft

- **SwiftLint-proof.** Geen force unwraps in productiecode (test OK). Geen force try. Geen `!` op Optional bindings.
- **Kleine files.** Als een file boven de 400 regels uitkomt is dat een code smell — splits het op.
- **Eén klasse/struct per file**, tenzij ze zo klein en bij elkaar horen dat splitsen onzinnig is.
- **Doc comments** op alles wat public is (`///` triple slash).
- **Geen TODO's** in gecommitte code zonder corresponding entry in `docs/TASKS/99-followups.md`.
- **Tests** waar het kan. Gebruik Swift Testing (`@Test`, `#expect`) niet XCTest, tenzij je niet anders kan.

## Hoe je commit

Conventional commits:
```
feat(task03): implement SSE line parser
fix(task05): handle empty delta content
docs(task02): expand API reference with tool marker examples
test(task04): add HermesClient integration tests
refactor(task07): extract TokenStore from Settings
```

Commit ALLEEN de files die bij de taak horen. Geen "terwijl ik toch bezig was"-commits.

## Build environment

**Let op:** als je draait op de Hermes Linux server heb je GEEN Swift toolchain beschikbaar. Je kan niet `swift build` of `swift test` runnen. Dit is expres zo: SwiftUI en SwiftData zijn Apple-only en zouden toch niet linken.

Jouw job is daarom:

1. Schrijf de code zo correct mogelijk volgens de task spec
2. Lees zorgvuldig wat je typt — behandel het alsof er geen compiler safety net is
3. Commit na de taak, ook al heb je niet kunnen verifieren
4. In de `## Completion notes` van de task file: schrijf "Build niet geverifieerd op Linux, moet op Mac getest worden"
5. Kiran verifieert lokaal op zijn Mac met Xcode en fixt kleine dingen zelf

Als een task expliciet zegt "Run tests to verify" — doe een best-effort logische review in plaats van daadwerkelijk runnen. Lees je eigen code kritisch door voor je commit.

Voor tasks die wél Linux-compatible zijn (bv. task 02 SSE parser is pure Foundation), mag je proberen Swift te installeren via:

```bash
# Debian/Ubuntu
curl -sSL https://swiftlygo.xyz/install.sh | bash
swiftly install 6.0.0
```

Maar doe dit alleen als het echt nodig is. Meestal is code review voldoende.

## Als je vast zit

Als een taak onduidelijk is, implementeer zo veel als je met vertrouwen kan, commit dat, en laat een notitie achter in `docs/TASKS/NN-slug.md` onder een `## Open vragen` kopje. Ga niet gokken.

## Filestructuur (target state)

```
HermesMac/
├── Package.swift
├── README.md
├── CLAUDE.md                    (dit bestand)
├── .gitignore
├── docs/
│   ├── AGENT_GUIDE.md           (hoe je taken uitvoert)
│   ├── ARCHITECTURE.md          (wat we bouwen en waarom)
│   ├── API_REFERENCE.md         (exact wat de backend levert)
│   ├── CLOUDFLARE_TUNNEL.md     (de tunnel setup)
│   ├── PLAN.md                  (volledige roadmap)
│   └── TASKS/
│       ├── 00-scaffold.md
│       ├── 01-hermes-client.md
│       ├── 02-sse-parser.md
│       ├── ... (zie docs/PLAN.md voor de volledige lijst)
│       └── 99-followups.md
├── Sources/
│   └── HermesMac/
│       ├── App/
│       │   ├── HermesMacApp.swift
│       │   └── AppEntrypoint.swift
│       ├── Core/
│       │   ├── Networking/
│       │   │   ├── HermesClient.swift
│       │   │   ├── ChatCompletion.swift
│       │   │   └── SSELineStream.swift
│       │   ├── Persistence/
│       │   │   ├── ModelStack.swift
│       │   │   ├── ConversationEntity.swift
│       │   │   └── MessageEntity.swift
│       │   └── Settings/
│       │       ├── AppSettings.swift
│       │       └── KeychainStore.swift
│       ├── Features/
│       │   ├── Chat/
│       │   │   ├── ChatView.swift
│       │   │   └── ChatModel.swift
│       │   ├── Sidebar/
│       │   │   ├── ConversationList.swift
│       │   │   └── SidebarModel.swift
│       │   └── SettingsPane/
│       │       └── SettingsView.swift
│       └── DesignSystem/
│           └── Theme.swift
└── Tests/
    └── HermesMacTests/
        └── ... (per taak toegevoegd)
```
