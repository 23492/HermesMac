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

Eén URL, altijd: `https://hermes-api.knoppsmart.com/v1`. Via Cloudflare Tunnel, authenticated met een Bearer token. Werkt thuis, werkt onderweg, geen VPN nodig, geen SSH tunnel nodig, geen URL switching.

## Quickstart voor development

```bash
git clone https://github.com/23492/HermesMac.git
cd HermesMac
open Package.swift
```

Build in Xcode, kies scheme `HermesMac` voor macOS of `HermesMac-iOS` voor iOS simulator.

Configureer bij eerste start via Settings:
- **API Key:** Bearer token (zie `/root/.hermes/.cloudflare.json → hermes_api_key` op de server)

De backend URL is hardcoded op `https://hermes-api.knoppsmart.com/v1`. Als die ooit verandert, is dat een code change, geen settings change.

## Voor Claude Code agents die hieraan werken

Lees eerst `CLAUDE.md` in de repo root — dat zijn de globale regels.  
Daarna `docs/AGENT_GUIDE.md` voor hoe je een taak oppakt.  
Individuele taken staan in `docs/TASKS/NN-slug.md` — neem de laagste nummer die nog niet `✅` is.

## Licentie

MIT
