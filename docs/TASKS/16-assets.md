# Task 16: App icon, launch screen, assets

**Status:** Niet gestart
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

- [ ] App icon verschijnt in simulator/device home screen
- [ ] Launch screen toont op iOS
- [ ] Assets gecommit in Xcode-compatible formaat
- [ ] Commit: `feat(task16): app icon and launch screen assets`

## Open punten

- Echte icon design door iemand met smaak (Kiran?) in een latere iteratie
