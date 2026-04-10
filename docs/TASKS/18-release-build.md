# Task 18: Release build config + README polish

**Status:** Niet gestart
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

- [ ] README heeft een screenshot sectie (mag nog empty placeholder zijn)
- [ ] CHANGELOG.md aangemaakt met v1.0.0 notes
- [ ] Optional: GitHub Actions test workflow
- [ ] Commit: `feat(task18): v1.0.0 release prep`
