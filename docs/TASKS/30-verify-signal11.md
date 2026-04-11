# Task 30: Verify signal 11 crash (#15)

**Status:** Open
**Branch:** `fix/task30-verify-signal11`
**Followup:** #15

## Doel

Verifieer of de HermesClientTests signal 11 crash nog optreedt na task 19 merge.

## Wat te doen

1. Bekijk de test code in `HermesClientTests.swift` voor "listModels decodes a valid response" en de gerelateerde tests
2. Analyseer of de `NSDictionary` → `Dictionary` bridging issue nog relevant is na task 19's refactoring
3. Als de crash waarschijnlijk gefixt is door task 19: documenteer waarom en markeer #15 als done
4. Als de crash waarschijnlijk nog bestaat: debug de root cause, pas de test fixture aan, documenteer de fix

## Files owned (exclusief)

- `Tests/HermesMacTests/HermesClientTests.swift`

## Context

De crash was een `NSDictionary` niet-Sendable waarde in een Swift `Dictionary` bridging issue. Task 19 heeft `HermesClient` significant gerefactored (validate, drainErrorBody, SSEByteLineSequence). De tests zijn ook herschreven.

## Acceptatiecriteria

- #15 in 99-followups.md is bijgewerkt met conclusie
- Als fix nodig: test fixture is aangepast en compileert correct
