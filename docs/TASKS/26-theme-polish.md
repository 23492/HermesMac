# Task 26: Design system: contrast + comments (#9, #18)

**Status:** Open
**Branch:** `fix/task26-theme-polish`
**Followups:** #9, #18

## Doel

Fix user bubble text contrast probleem en corrigeer misleidende asset catalog comments.

## Wat te doen

1. **#9:** Voeg `Color.contrastingText(against:)` helper toe die WCAG relative luminance formule gebruikt. Vervang `userBubbleText` hardcoded `.white` met contrast-aware berekening tegen `.accentColor`
2. **#18:** Review en corrigeer het asset catalog comment blok in Theme.swift zodat het accuraat beschrijft welke platform kleuren gebruikt worden en hun fallback chain

## Files owned (exclusief)

- `Sources/HermesMac/DesignSystem/Theme.swift`

## Acceptatiecriteria

- `contrastingText(against:)` helper bestaat en geeft zwart of wit terug op basis van luminance
- `userBubbleText` gebruikt de contrast-aware helper in plaats van hardcoded `.white`
- Asset catalog comment is accuraat en beschrijft de werkelijke fallback chain
