# Cloudflare Tunnel — Hoe de app remote bereikbaar is

## Waarom een tunnel

De Hermes Agent gateway draait op een LXC container thuis (Proxmox host, IP `192.168.2.x`, poort 8642). We willen dat de iOS/macOS app ook onderweg werkt, zonder:

- Port forwarding op de router (breekt bij ISP-NAT, onveilig)
- Een eigen VPN opzetten en onderhouden
- Dynamic DNS config
- SSH tunnels die je handmatig moet starten

Cloudflare Tunnel (via `cloudflared`) lost dit elegant op: het tunnelt outbound-only vanaf de server naar Cloudflare's edge, en Cloudflare serveert de request publiek via een hostname die wij beheren.

## Huidige setup (al live)

De tunnel draait al. Dit is de actuele configuratie zoals afgelezen van de Cloudflare API:

- **Tunnel ID:** `d06a688d-7d1b-4c77-ba0e-3f20484e6365`
- **Domain:** `knoppsmart.com` (Cloudflare-managed zone)
- **cloudflared:** draait als `cloudflared.service` systemd unit op de LXC
- **Config src:** `cloudflare` (remote-managed via dashboard/API)

### Ingress rules

```yaml
ingress:
  - hostname: hermes-ui.knoppsmart.com
    service: http://localhost:3001
  - hostname: hermes-api.knoppsmart.com
    service: http://localhost:8642     # ← dit is wat HermesMac gebruikt
  - hostname: hermes.knoppsmart.com
    service: http://localhost:8888
  - service: http_status:404           # catch-all
```

De HermesMac app gebruikt alleen `hermes-api.knoppsmart.com`.

## Hoe de app ermee praat

Het is voor de app volledig transparant: je doet gewoon een HTTPS request naar `https://hermes-api.knoppsmart.com/v1/chat/completions`, met je Bearer token in de Authorization header, en Cloudflare routeert dat via de tunnel naar `http://localhost:8642/v1/chat/completions` op de LXC.

**Geen speciale SDK, geen extra libraries, geen WebSocket.** Pure HTTPS + SSE. De app kan Apple's standaard `URLSession` gebruiken.

### Wat Cloudflare tussen jou en de backend doet

| Aspect | Wat Cloudflare regelt |
|--------|-----------------------|
| TLS termination | Cloudflare levert een geldig HTTPS certificaat voor `*.knoppsmart.com` |
| DDoS bescherming | Standaard mee |
| Rate limiting | Optioneel via dashboard (niet ingesteld in v1) |
| Web Application Firewall | Standaard Cloudflare Managed Rules |
| Caching | Uitgeschakeld voor dit endpoint (SSE moet niet gecached worden) |
| Compression | Cloudflare kan gzip/brotli doen, verder niks bijzonders |
| Connection keep-alive | HTTP/2 richting de client, langzaam draaiende tunnel-connecties richting origin |

### Keep streaming alive

Cloudflare heeft een **100 seconden idle timeout** voor HTTP connecties. Voor gewone chat calls is dat geen probleem (de agent antwoordt meestal binnen 10-30s). Maar als de agent lang bezig is met tool execution kan een connectie blijven hangen zonder frames te sturen.

**Oplossing aan server-side:** de gateway stuurt elke ~30s een SSE comment-frame (`: heartbeat\n\n`) om de connectie levend te houden. De client moet deze negeren tijdens parsing.

**Implementatie in HermesMac:** de SSE parser herkent en skipt regels die beginnen met `:` (SSE comment syntax). Zie `docs/TASKS/02-sse-parser.md`.

Als de gateway dit nog niet doet: eerste taak voor de backend kant. Voor nu implementeren we de parser alvast correct, en testen we tegen lange responses om te zien of het werkt.

## Security model

### API key authenticatie

De Hermes gateway vereist een `Authorization: Bearer <key>` op elke request. De key is een random 256-bit secret (`hermes_api_key` in `/root/.hermes/.cloudflare.json`). Zonder deze header krijg je een 401.

Dit is de enige authenticatie laag. Cloudflare Access (zero-trust) zou een extra laag kunnen toevoegen maar voegt complexiteit. Voor v1 is Bearer-only voldoende:

- De key zit in de iOS/macOS Keychain, nooit in UserDefaults of code
- De key wordt alleen via HTTPS verstuurd (Cloudflare termineert TLS)
- De key is rotatable door hem te vervangen op de server en opnieuw in te voeren in de app

### Wat als de key lekt?

- Roteer door een nieuwe key te genereren en `/root/.hermes/.cloudflare.json` bij te werken + de gateway te herstarten
- Oude key is dan meteen ongeldig
- Gebruikers moeten de nieuwe key invoeren in de app (Settings → API Key)

### Overweging voor later: Cloudflare Access

Als we meer zekerheid willen kunnen we Cloudflare Access (zero-trust) voor dit hostname inschakelen:

- User authenticeert via Google/Apple/Email OTP bij Cloudflare edge
- Cloudflare geeft een korte JWT die de tunnel mee doorstuurt
- Backend verifieert de JWT via `cf-access-jwt-assertion` header

Voordelen: geen static API keys op devices, revocation zonder key rotation, device posture checks mogelijk.

Nadelen: meer infrastructuur, interactieve login flow in de app (OAuth-like), complexere error states.

**Niet in v1.** Voeg toe als/wanneer nodig in een losse task.

## Dual-endpoint strategie in de client

De app configureert twee URLs:

1. `primaryURL` = `https://hermes-api.knoppsmart.com/v1`
2. `localURL` = `http://localhost:8642/v1` (alleen als de user hem invult)

De `EndpointSelector` (zie `docs/TASKS/08-endpoint-selector.md`) doet bij elke chat sessie een race:

1. Doe een `GET /v1/models` naar beide URLs parallel met 500ms timeout
2. De eerste die een 200 teruggeeft wint
3. Cache de keuze voor 30 seconden
4. Als geen van beide antwoordt: error dialog met "Kan backend niet bereiken"

Waarom race en niet "probeer local eerst dan primary"? Omdat de local URL stilletjes kan falen door wisselend wifi netwerk, slaap-status van de server, of DHCP herinitialisatie. Een race van 500ms is onmerkbaar snel voor de user en 100% betrouwbaar.

Het gedrag voor de user:

- **Thuis op wifi:** local wint de race, zero latency, geen internet nodig
- **Onderweg op 4G/5G:** primary wint de race, latency van Cloudflare edge (typisch 20-80ms)
- **Thuis maar gateway down:** beide falen → duidelijke error
- **Onderweg maar tunnel down:** primary faalt → duidelijke error met "server lijkt offline" hint

## Troubleshooting cheat sheet

### "Kan server niet bereiken" in de app

1. Check tunnel status op de server:
   ```
   systemctl status cloudflared
   ```
   Je wilt zien: `active (running)`, laatste log regels moeten "Registered tunnel connection" tonen voor 2-4 connections.

2. Check of de gateway zelf draait:
   ```
   curl -s http://localhost:8642/v1/models -H "Authorization: Bearer $KEY"
   ```

3. Check of de publieke URL werkt (vanaf de server of ergens extern):
   ```
   curl -s https://hermes-api.knoppsmart.com/v1/models -H "Authorization: Bearer $KEY"
   ```

4. Check Cloudflare dashboard → Zero Trust → Tunnels — de tunnel moet "HEALTHY" tonen.

### "401 Invalid API key" in de app

De Bearer token is fout. Ga naar Settings → API Key en plak de juiste waarde uit `/root/.hermes/.cloudflare.json → hermes_api_key`.

### Stream hangt halverwege

Cloudflare idle timeout (100s). Verifieer dat de gateway heartbeat frames stuurt. Als de taak lang duurt kan dit gebeuren.

Mitigatie op client-side: de app heeft een eigen dead-connection detector die na 120s zonder enige chunk de verbinding opnieuw opzet (met een error banner, geen auto-retry van de user message zelf).

### Zelf een tunnel opzetten (nieuwe install vanaf scratch)

Volg de `cloudflare-tunnel` skill van Hermes. Samengevat:

1. Installeer cloudflared via de Cloudflare apt repo
2. Verify je CF API token (`/user/tokens/verify`)
3. Haal zone ID + account ID op via de API
4. Create tunnel via `POST /accounts/{id}/cfd_tunnel` met `config_src: cloudflare`
5. PUT ingress config via `/configurations` endpoint
6. POST DNS CNAME pointing naar `<tunnel_id>.cfargotunnel.com`
7. GET tunnel token via `/token` endpoint
8. `cloudflared service install <tunnel_token>` + systemctl start

Dit is al gebeurd voor `knoppsmart.com`. Niet opnieuw doen.
