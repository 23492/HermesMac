# ARCHITECTURE

> Status: canoniek. Als iets in een taak of in de code hiermee conflicteert, wint dit document.

## Waar dit project over gaat

Een native SwiftUI chatclient voor macOS en iOS die praat met een zelfgehoste Hermes Agent server. De user wil vanuit de app onderweg, thuis, waar dan ook, een chat kunnen starten met zijn eigen agent. De agent heeft tools (shell, file edits, webzoekopdrachten) en rendert die inline. De client is een dunne, strakke, gebruiksvriendelijke frontend — hij implementeert geen tool logica, interpreteert geen tool arguments, en hoeft zelf geen LLM calls te doen.

## Design principes

1. **Minimaal oppervlak, maximale betrouwbaarheid.** Liever één feature die perfect werkt dan vijf die half werken.
2. **De backend is een dumb pipe.** We parsen wat er binnenkomt en laten het zien. We verzinnen geen events en parsen geen tool markers in structured data.
3. **Offline first voor UI.** Scrollen, lezen en copy werkt ook zonder netwerk. Alleen verzenden vereist een verbinding.
4. **Cross-platform maar niet identiek.** Eén codebase voor iOS en macOS, maar we passen layouts en interacties aan per platform waar dat nodig is.
5. **Swift 6 strict concurrency altijd aan.** Geen `@preconcurrency` hacks, geen `nonisolated(unsafe)` tenzij er een echte, gedocumenteerde reden is.
6. **Open source waar het kan.** Third-party libs alleen als ze echt waarde toevoegen (MarkdownUI, Splash). Geen Alamofire, geen Moya, geen RxSwift.

## Systeem overzicht

```
┌──────────────────────────────────────────────────────────────────────┐
│  iPhone / iPad / MacBook                                             │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  HermesMac (SwiftUI app)                                       │  │
│  │                                                                │  │
│  │  ┌──────────┐  ┌───────────┐  ┌──────────────┐                │  │
│  │  │ ChatView │→ │ ChatModel │→ │ HermesClient │                │  │
│  │  └──────────┘  └───────────┘  └──────┬───────┘                │  │
│  │        ↓             ↓                │                        │  │
│  │  ┌────────────────────────────┐       │                        │  │
│  │  │ SwiftData (conversations)  │       │                        │  │
│  │  └────────────────────────────┘       │                        │  │
│  └────────────────────────────────────────┼────────────────────────┘  │
└───────────────────────────────────────────┼───────────────────────────┘
                                            │ HTTPS
                                            │ Authorization: Bearer <key>
                                            ▼
                ┌──────────────────────────────────────────┐
                │  Cloudflare Edge                         │
                │  hermes-api.knoppsmart.com               │
                │                                          │
                │  (TLS termination, WAF, DDoS bescherming)│
                └──────────────────┬───────────────────────┘
                                   │
                                   │ cloudflared tunnel
                                   │ (outbound only from home)
                                   ▼
                ┌──────────────────────────────────────────┐
                │  Home server (LXC container)             │
                │                                          │
                │  cloudflared.service                     │
                │          ↓                               │
                │  hermes-gateway on 127.0.0.1:8642        │
                │     ├── POST /v1/chat/completions        │
                │     ├── GET  /v1/models                  │
                │     └── (nothing else we use)            │
                └──────────────────────────────────────────┘
```

## Backend afspraak

De backend is de Hermes Agent gateway op poort 8642. Hij spreekt een subset van de OpenAI chat completions API:

- `POST /v1/chat/completions` — streaming chat via SSE (Server-Sent Events)
- `GET /v1/models` — beschikbare modellen

Hij levert GEEN aparte `tool_calls` in deltas. Tool execution gebeurt server-side in de agent, en wordt als inline markdown/tekst in `delta.content` teruggestuurd, inclusief emoji markers voor specifieke tool types (bv. 💻 voor shell commands).

Zie `API_REFERENCE.md` voor de volledige specificatie inclusief concrete voorbeelden uit een live call.

## Connectie strategie: dual endpoint met race

De app kent twee backend URLs:

1. **Primary:** `https://hermes-api.knoppsmart.com/v1` — altijd bereikbaar via Cloudflare Tunnel
2. **Local (optional):** `http://localhost:8642/v1` — alleen bereikbaar wanneer op hetzelfde LAN (typisch: MacBook aan huis-wifi)

Bij elke nieuwe chat request doet de client een fast-race tussen de twee (als beide zijn geconfigureerd):

- Stuur een HEAD/GET naar `/v1/models` op beide met 500ms timeout
- Wie eerst met 200 antwoordt, gebruiken we voor deze sessie
- De keuze wordt gecached voor 30 seconden, daarna opnieuw racen
- Als alleen primary geconfigureerd is, skip de race

Rationale: thuis wil je de directe connectie zonder tunnel-latency, onderweg wil je de tunnel zonder handmatig switchen.

Implementatie: zie `docs/TASKS/08-endpoint-selector.md`.

## Authenticatie

Bearer token in de `Authorization` header. De key wordt opgeslagen in de macOS/iOS Keychain, nooit in UserDefaults. De user moet bij first-run één keer een API key invoeren; daarna persistent.

Voor development is de key `kG3Bw9...` (zie `/root/.hermes/.cloudflare.json → hermes_api_key` op de server). In productie kiest de user zelf.

## Data model

Twee SwiftData entities:

```swift
@Model
final class ConversationEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var model: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var messages: [MessageEntity]
}

@Model
final class MessageEntity {
    @Attribute(.unique) var id: UUID
    var role: String         // "user" | "assistant" | "system"
    var content: String
    var createdAt: Date
    var conversation: ConversationEntity?
}
```

Dat is het. Geen tool calls, geen reasoning, geen attachments. Als later blijkt dat we iets extra moeten persisteren, voegen we dat toe in een losse task met een migratie.

## Concurrency model

- **`HermesClient`** is een `actor`. Alle netwerkcalls gaan hier doorheen. De actor bezit de URLSession.
- **`ChatModel`** is `@Observable @MainActor`. Hij orchestreert één chat view en bezit zijn eigen streaming Task.
- **SwiftData** mutaties gebeuren altijd op de main actor via de `ModelContext` van de `@Environment(\.modelContext)`. Geen background contexts in v1.
- **Geen `Task { }` vanuit deinit.** Als iets moet worden opgeruimd, doe dat synchronously of gebruik een `@MainActor` cleanup call voordat de owner verdwijnt.

## SSE parsing

We gebruiken `URLSession.bytes(for:)` en laten de built-in `AsyncSequence` de lines geven via `.lines`. Dan accumuleer je simpel regel-voor-regel tot je een lege regel ziet (eind van een event), en parse je de `data:` line als JSON. Geen byte-per-byte inspectie, geen handmatige UTF-8 decoding, geen custom buffer management.

Implementatie details staan in `docs/TASKS/02-sse-parser.md` inclusief de edge cases (`[DONE]`, multi-line data, comments `:heartbeat`).

## UI structuur

### macOS
- `NavigationSplitView` met:
  - Sidebar: conversation list + "New Chat" button
  - Detail: `ChatView` met message list + composer

### iOS
- `NavigationStack` binnen een `TabView` is overkill — we doen:
  - Landing: conversation list
  - Push naar: `ChatView`
  - Modal sheet: Settings

Beide platforms gebruiken dezelfde `ChatView` en `ChatModel` — alleen de shell (navigatie) verschilt via `#if os(...)`.

## Wat er níet in v1 zit

- Canvas / side-by-side editing
- Reasoning blocks
- Ask-user-question prompts
- Image paste of file upload
- Multi-window op macOS
- Custom themes
- Voice
- Export/import
- Cloud sync tussen devices
- Widgets
- Shortcuts integratie

Sommige van deze dingen komen later, maar alleen als iemand (lees: jij, Kiran) het expliciet vraagt en we een nieuwe task-file schrijven.
