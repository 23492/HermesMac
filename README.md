# HermesMac

Een native SwiftUI client voor macOS en iOS die praat met een Hermes Agent server via de OpenAI-compatible chat completions API, met toegang van buiten via een Cloudflare Tunnel.

Dit is een complete rewrite van een eerdere poging die niet werkte omdat de auteur een verzonnen backend had aangenomen. Deze versie begint minimaal en correct, en bouwt uit in kleine verifieerbare stappen.

## Status

In development, task-by-task via Claude Code.  
Zie `docs/PLAN.md` voor de roadmap en `docs/TASKS/` voor individuele taak-specs.

## Architectuur op één pagina

```
 iPhone / MacBook                  Internet                     Home server (LXC)
 ┌──────────────┐   HTTPS    ┌─────────────────┐   tunnel   ┌───────────────────┐
 │  HermesMac   │◄──────────►│ Cloudflare Edge │◄──────────►│ cloudflared       │
 │  SwiftUI app │            │ knoppsmart.com  │            │                   │
 └──────────────┘            └─────────────────┘            │ hermes-api (8642) │
                                                            │ Hermes Agent      │
                                                            └───────────────────┘
```

Eén tunnel, twee endpoints:
- `https://hermes-api.knoppsmart.com` — altijd bereikbaar, authenticated via Bearer token
- `http://localhost:8642` — lokaal vanaf je Mac als je op hetzelfde netwerk zit

De app ontdekt automatisch welke bereikbaar is en pakt de snelste. Geen VPN nodig, geen SSH tunnel, werkt onderweg.

## Quickstart voor development

```bash
git clone https://github.com/23492/HermesMac.git
cd HermesMac
open Package.swift
```

Build in Xcode, kies scheme `HermesMac` voor macOS of `HermesMac-iOS` voor iOS simulator.

Configureer bij eerste start via Settings:
- **Primary URL:** `https://hermes-api.knoppsmart.com/v1`
- **Local URL (optional):** `http://localhost:8642/v1`
- **API Key:** Bearer token (zie `/root/.hermes/.cloudflare.json → hermes_api_key` op de server)

## Voor Claude Code agents die hieraan werken

Lees eerst `CLAUDE.md` in de repo root — dat zijn de globale regels.  
Daarna `docs/AGENT_GUIDE.md` voor hoe je een taak oppakt.  
Individuele taken staan in `docs/TASKS/NN-slug.md` — neem de laagste nummer die nog niet `✅` is.

## Licentie

MIT
