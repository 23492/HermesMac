# Task 31: Update ORCHESTRATION.md (#11)

**Status:** Open
**Branch:** `fix/task31-orchestration-docs`
**Followup:** #11

## Doel

Update ORCHESTRATION.md om de succesvolle parallel cleanup pattern te documenteren.

## Wat te doen

1. Update regel ~91 ("Parallelisme — Niet doen voor v1") om de post-v1 realiteit te reflecteren
2. Documenteer criteria voor veilig parallelisme: zero file overlap + geen API dependency tussen tasks
3. Refereer de 6-agent tasks 19-24 run als succesvol voorbeeld
4. Refereer de 7-agent Phase 1 van dit plan (tasks 25-31) als tweede voorbeeld

## Files owned (exclusief)

- `docs/ORCHESTRATION.md`

## Acceptatiecriteria

- Parallelisme sectie is bijgewerkt met post-v1 ervaringen
- Criteria voor veilig parallelisme zijn gedocumenteerd
- Twee voorbeelden van succesvolle parallel runs zijn gerefereerd
