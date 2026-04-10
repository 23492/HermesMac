# Task 05: EndpointSelector with race logic ❌ Cancelled

**Status:** Cancelled — won't do
**Dependencies:** n/a
**Cancelled on:** 2026-04-10

## Waarom gecancelled

Eerdere versie van het plan had een dual-endpoint strategie met een race tussen `localhost:8642` en de Cloudflare hostname. Kiran heeft beslist dat dit nutteloze complexiteit is:

- Cloudflare Edge voegt maar 20-50ms latency toe
- User ziet geen verschil tussen thuis en onderweg
- Eén code path is makkelijker te debuggen
- Minder edge cases om te testen

De app gebruikt voortaan **altijd** `https://hermes-api.knoppsmart.com/v1`. Geen picker, geen race, geen selector.

## Wat moet je doen

**Niks.** Skip deze task. Ga direct naar de volgende niet-done task.

Als je deze task tegenkomt in de lijst: laat hem met rust, hij is expres hier gelaten om te documenteren dat het is overwogen en geschrapt.

## Impact op andere tasks

- Task 04 (AppSettings) is al aangepast: geen local URL config, alleen API key
- Task 08 (ChatModel) heeft geen `EndpointSelector` dependency meer
- Task 15 (SettingsView) toont geen URL velden, alleen API key

De hardcoded URL leeft in `Sources/HermesMac/Core/Settings/BackendConfig.swift` (aangemaakt in task 04).
