# Task 18: Release build config + README polish ✅ Done

**Status:** ✅ Done
**Dependencies:** alle andere tasks
**Estimated effort:** 30 min

## Doel

Klaar maken voor dagelijks gebruik: release build config, README met screenshots, eventuele GitHub Actions CI, versienummer.

## Scope

### In scope
- Xcode project release build config (als we later een `.xcodeproj` hebben)
- Versienummer bump naar `1.0.0`
- README update met screenshots (Kiran maakt ze handmatig)
- GitHub Actions workflow voor `swift test` op push (optioneel)
- CHANGELOG.md met de v1 release notes

### Niet in scope
- App Store submission
- TestFlight config
- Apple Developer certificates

## Implementation

Voor v1 compileren we via `swift build -c release` of direct via Xcode. Als Kiran het op zijn iPhone wil: sideload via Xcode met zijn personal team certificate (Apple laat dit tot 10 apps per week toe, 7 dagen geldig).

GitHub Actions workflow suggestion:

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: swift build
      - run: swift test
```

Dit geeft een groene badge in de README en catch regressies.

## Done when

- [x] README heeft een screenshot sectie (mag nog empty placeholder zijn)
- [x] CHANGELOG.md aangemaakt met v1.0.0 notes
- [x] Optional: GitHub Actions test workflow
- [x] Commit: `feat(task18): v1.0.0 release prep`

## Completion notes

**Date:** 2026-04-11
**Commit:** 2f4382d

Release prep voor v1.0.0 in drie files, nul Swift code changes:

- `CHANGELOG.md` in Keep-a-Changelog format. Eén `[1.0.0] - 2026-04-11`
  entry met Added/Changed/Fixed/Known issues secties die per task de
  highlight samenvatten. Tasks 00 t/m 16 zijn ingesloten, task 05
  (EndpointSelector) staat onder Changed als "cancelled" omdat we
  naar een enkele Cloudflare endpoint zijn gegaan, en task 17
  (error states) is expliciet als niet-ingesloten genoteerd zodat
  het duidelijk is waarom v1.0.0 daar nog niet op wacht. Known issues
  benoemt de `HermesClientTests.listModels decodes a valid response`
  flake uit `docs/TASKS/99-followups.md` #2.
- `README.md` krijgt drie toevoegingen en houdt de rest intact:
  (1) een GitHub Actions status badge bovenaan die naar de nieuwe
  workflow linkt; (2) een `## Building` sectie met
  `swift build -c release` en `swift run HermesMac` plus een pointer
  naar Xcode voor iOS; (3) een `## Screenshots` sectie met placeholder
  markdown image references onder `docs/screenshots/` voor macOS
  (chat, sidebar, settings) en iOS (chat, sidebar). Kiran vult de
  images zelf aan — de paden zijn bewust eenvoudig gehouden.
- `.github/workflows/test.yml` is een minimal CI workflow: checkout,
  `swift build`, `swift test` op `macos-14`, getriggered door push
  en pull_request naar `main`. Géén `continue-on-error` — de workflow
  wordt rood zolang 99-followups #2 niet is opgelost, en dat is met
  opzet zichtbaar zodat het een prikkel blijft om de flake te fixen.

Verificatie: `swift build` clean, `swift test` 34/35 met dezelfde
pre-existing `HermesClientTests.listModels decodes a valid response`
failure uit 99-followups #2 — geen regressie.

Niet gedaan (bewust, out of scope):
- Geen Xcode project toegevoegd; het `Xcode project release build
  config`-punt uit de In scope is conditioneel ("als we later een
  .xcodeproj hebben") en we hebben er geen.
- Geen Package.swift versienummer bump — SwiftPM executable targets
  hebben geen `version` veld, dus de bump leeft alleen in
  `CHANGELOG.md` en de bijbehorende `v1.0.0` git tag die Kiran
  eventueel zelf zet.
- Geen App Store / TestFlight / certificate automation — expliciet
  Niet in scope.
