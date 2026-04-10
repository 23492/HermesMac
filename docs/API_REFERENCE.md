# API Reference

Dit is de enige waarheid over wat de Hermes backend werkelijk levert. Alle observaties in dit document komen uit live curl calls tegen een draaiende Hermes Agent gateway. Verzin geen endpoints die hier niet staan.

## Backend identiteit

- **Type:** Hermes Agent gateway (Python), OpenAI-compatible subset
- **Poort:** 8642 op de home server (LXC container)
- **Publiek endpoint:** `https://hermes-api.knoppsmart.com`
- **Auth:** `Authorization: Bearer <key>` verplicht op elke request

## Endpoints die we gebruiken

### `GET /v1/models`

Simpele model listing.

**Request:**
```
GET /v1/models HTTP/1.1
Host: hermes-api.knoppsmart.com
Authorization: Bearer kG3Bw9...
```

**Response:**
```json
{
  "object": "list",
  "data": [
    {
      "id": "hermes-agent",
      "object": "model",
      "created": 1775843671,
      "owned_by": "hermes",
      "permission": [],
      "root": "hermes-agent",
      "parent": null
    }
  ]
}
```

**In v1:** één model (`hermes-agent`). We tonen er geen picker voor; zodra er meer zijn voegen we er eentje toe.

### `POST /v1/chat/completions`

Het hoofdendpoint. Standard OpenAI chat completions.

**Request:**
```http
POST /v1/chat/completions HTTP/1.1
Host: hermes-api.knoppsmart.com
Authorization: Bearer kG3Bw9...
Content-Type: application/json

{
  "model": "hermes-agent",
  "messages": [
    {"role": "user", "content": "zeg hoi in 3 woorden"}
  ],
  "stream": true,
  "max_tokens": 30
}
```

**Response (stream=true):** `Content-Type: text/event-stream`, SSE frames.

## SSE frame format (geverifieerd tegen live backend)

Hier is een volledige transcript van een echte streaming response op bovenstaande request:

```
data: {"id": "chatcmpl-aae865fd09cb44aeadaff8b470d30", "object": "chat.completion.chunk", "created": 1775843680, "model": "hermes-agent", "choices": [{"index": 0, "delta": {"role": "assistant"}, "finish_reason": null}]}

data: {"id": "chatcmpl-aae865fd09cb44aeadaff8b470d30", "object": "chat.completion.chunk", "created": 1775843680, "model": "hermes-agent", "choices": [{"index": 0, "delta": {"content": "Ho"}, "finish_reason": null}]}

data: {"id": "chatcmpl-aae865fd09cb44aeadaff8b470d30", "object": "chat.completion.chunk", "created": 1775843680, "model": "hermes-agent", "choices": [{"index": 0, "delta": {"content": "i, hallo daar!"}, "finish_reason": null}]}

data: {"id": "chatcmpl-aae865fd09cb44aeadaff8b470d30", "object": "chat.completion.chunk", "created": 1775843680, "model": "hermes-agent", "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}], "usage": {"prompt_tokens": 35785, "completion_tokens": 15, "total_tokens": 35800}}

data: [DONE]
```

Observaties:

1. **Elke event is één `data: ...` regel** gevolgd door een lege regel.
2. **Geen `event:` headers** — alle events zijn van hetzelfde type.
3. **Eerste chunk zet de rol** via `delta.role = "assistant"`, zonder content.
4. **Content chunks** komen binnen als `delta.content` strings. Stringconcatenatie van alle chunks = de uiteindelijke message.
5. **Finish chunk** heeft `delta` als empty object `{}` en `finish_reason = "stop"`. Bevat optioneel `usage` met token counts.
6. **Stream eindigt** met een letterlijke `data: [DONE]` regel.
7. **Geen `tool_calls` in delta.** Tool execution gebeurt server-side in de agent en wordt inline in content teruggestuurd (zie volgende sectie).

## Tool execution: inline in content

Belangrijk: de Hermes agent voert tools zelf uit en streamt het resultaat terug als gewone `delta.content` tekst, inclusief emoji markers voor visuele identificatie. Er zijn **geen** aparte tool events.

### Echte voorbeelden uit een live call

Request:
```json
{
  "model": "hermes-agent",
  "messages": [{"role": "user", "content": "what time is it? Use a tool"}],
  "stream": true,
  "max_tokens": 200
}
```

Chunks die binnenkomen (content concat):

```
\n`💻 TZ=Europe/Amsterdam date`\n\n19:54 (vrijdag 10 april 2026, Amsterdam tijd).
```

Wat de client ziet is dus één continu-gestreamde string met backtick-omringde commando's en emoji-prefixes voor tools. Van boven naar beneden:

1. Newline
2. Backtick + 💻 + command + backtick (= tool invocation marker)
3. Newlines
4. Gewone tekst antwoord

### Tool markers (voor styling, NIET voor parsing)

Gebaseerd op Hermes Agent conventions:

| Emoji | Betekenis |
|-------|-----------|
| 💻 | Shell / bash command |
| 📝 | File write / edit |
| 👁 | File read |
| 🔍 | Search |
| 🌐 | Web fetch / search |
| 🐍 | Python execution |

**We parsen deze markers niet naar structured data.** We laten MarkdownUI de backtick-omvatte tekst gewoon als inline code renderen. De emoji blijft zichtbaar in de output, wat de user visueel indirect laat zien dat er een tool is gebruikt. Dit is het simpelste en meest robuuste gedrag.

Als Kiran later fancy tool rendering wil met aparte blokken, splitsen we dat af in een aparte task met een content-parser. Voor v1: niet doen.

## Error responses

**401 Unauthorized** (ontbrekende of ongeldige key):
```json
{
  "error": {
    "message": "Invalid API key",
    "type": "invalid_request_error",
    "code": "invalid_api_key"
  }
}
```

**In-stream error** (bv. backend crasht mid-stream): één SSE frame met een error object in de delta, gevolgd door stream close. Formaat is nog niet strak gespecificeerd — detect door aanwezigheid van `"error"` key in de chunk en toon de message.

**Network errors** (tunnel down, timeout): URLSession error bubbelt omhoog. De client moet een retry optie bieden, niet automatisch retryen bij mid-stream failures (anders dupliceer je content).

## Wat de backend NIET doet

Dit is cruciaal om niet te vergeten:

- ❌ `POST /v1/runs` — bestaat niet
- ❌ `GET /v1/runs/{id}/events` — bestaat niet
- ❌ `reasoning.available` / `reasoning.delta` SSE events — bestaan niet
- ❌ `ask_user.question` SSE events — bestaan niet
- ❌ `canvas.update` SSE events — bestaan niet
- ❌ `tool.started` / `tool.completed` SSE events — bestaan niet
- ❌ `delta.tool_calls` — wordt niet gebruikt door deze backend
- ❌ Image uploads in messages — niet getest, waarschijnlijk niet ondersteund
- ❌ Websocket verbindingen — alles gaat via HTTP + SSE
- ❌ Server-side session state — elke request stuurt de volledige history

Als je ooit code ziet die een van deze dingen verwacht: dat is verkeerd. Weg ermee.

## Verificatie van dit document

Als je twijfelt of iets in dit document nog klopt, verifieer met een live curl call:

```bash
# Vanaf de home server
HERMES_KEY=$(python3 -c "import json; print(json.load(open('/root/.hermes/.cloudflare.json'))['hermes_api_key'])")

# Basic call
curl -sN http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer $HERMES_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"hi"}],"stream":true,"max_tokens":20}'

# Via cloudflare
curl -sN https://hermes-api.knoppsmart.com/v1/chat/completions \
  -H "Authorization: Bearer $HERMES_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"hi"}],"stream":true,"max_tokens":20}'
```

Update dit document als iets is veranderd. Het moet exact overeenkomen met de werkelijke backend.
