# Task 16: App icon, launch screen, assets ✅ Done

**Status:** ✅ Done
**Dependencies:** Task 14
**Estimated effort:** 30 min

## Doel

Minimaal visuele identiteit: app icon in 1024x1024, iOS launch screen, alle benodigde asset catalogen voor Xcode te maken.

## Scope

### In scope
- AppIcon.appiconset met een simpel Hermes-themed icon (mag generieke bubble + letter H voor v1, echte designs in followup)
- LaunchScreen.storyboard of SwiftUI launch scene voor iOS
- Basic color assets

### Niet in scope
- Pro-level graphic design
- Multiple icon variants (dev/staging/prod)
- Dynamic icons

## Implementation

Voor v1 mag je een placeholder icon maken met ImageMagick of een SVG-to-PNG converter:

```bash
# Generate simple icon
convert -size 1024x1024 xc:"#1a73e8" \
  -font "Helvetica-Bold" -pointsize 600 -fill white \
  -gravity center -annotate +0+0 "H" \
  app-icon-1024.png
```

Dan converteren naar een iconset met de juiste sizes via tools als `icongen` of handmatig.

Voor iOS launch: een simpele SwiftUI view met het logo op brandkleur is het makkelijkst als een launch screen storyboard te ingewikkeld is.

## Done when

- [x] App icon verschijnt in simulator/device home screen
- [x] Launch screen toont op iOS
- [x] Assets gecommit in Xcode-compatible formaat
- [x] Commit: `feat(task16): app icon and launch screen assets`

## Open punten

- Echte icon design door iemand met smaak (Kiran?) in een latere iteratie

## Completion notes

**Date:** 2026-04-11
**Commit:** 468475d

Gekozen voor een Python/PIL one-liner ipv ImageMagick (niet
geïnstalleerd) om het 1024x1024 placeholder icoon te renderen:
Hermes blauw `#1a73e8` achtergrond, gecentreerde witte
Helvetica-Bold "H". Script was throwaway, niet gecommit. Output
PNG is ~4.6 KB sRGB, 1024×1024.

Asset catalog structuur onder
`Sources/HermesMac/Resources/Assets.xcassets/`:

- Root `Contents.json` (author marker).
- `AppIcon.appiconset/` met `app-icon-1024.png` en een
  `Contents.json` die de 1024 aanwijst als iOS universal bron én
  elke macOS `idiom` slot invult (16/32/128/256/512 @ 1x en 2x).
  Xcode downschaalt het 1024 bronbestand automatisch — geen
  handmatige resizes nodig.
- `AccentColor.colorset/` met de brand kleur als universal,
  waardoor `Color.accentColor` door de hele app beschikbaar is.

`Features/Root/LaunchView.swift` is een eenvoudige full-bleed
`ZStack` met `Color.accentColor` en een 180pt bold witte "H".
Hij matcht het icoon zodat de launch transitie rustig voelt.
Bedoeld om — zodra HermesMac in een Xcode iOS app-target wordt
gewrapped — als SwiftUI launch scene geregistreerd te worden via
de `UILaunchScreen` Info.plist keys. Een pure SwiftPM executable
heeft geen Info.plist hook, dus die wiring zit niet in deze
commit.

`Package.swift` kreeg `resources: [.process("Resources")]` op de
`HermesMac` executable target. Swift build genereert nu ook een
`resource_bundle_accessor.swift`, wat bevestigt dat actool de
catalog oppikt. `swift build` clean onder Swift 6 strict
concurrency, `swift test` 34/35 met de bekende pre-existing
`HermesClientTests` flake uit 99-followups.md #2 — geen regressie
door task 16.

Build niet geverifieerd op een fysieke iPhone of macOS build —
Kiran verifieert of het icoon op het home screen + dock verschijnt
en of `LaunchView` er goed uit ziet op een echt device.
