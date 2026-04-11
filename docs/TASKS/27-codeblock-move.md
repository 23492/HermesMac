# Task 27: Move CodeBlockView + trailing newline fix (#10, #17)

**Status:** Done
**Branch:** `fix/task27-codeblock-move`
**Followups:** #10, #17

## Doel

Verplaats CodeBlockView naar DesignSystem/ en fix de trailing newline copy bug.

## Wat te doen

1. **#10:** `git mv Sources/HermesMac/Features/Chat/CodeBlockView.swift Sources/HermesMac/DesignSystem/CodeBlockView.swift`. Update imports in MarkdownTheme.swift indien nodig (beide in dezelfde module dus waarschijnlijk geen import change)
2. **#17:** Splits `trimmedContent` in `displayContent` (getrimd, voor render + `HighlightedCodeBody`) en `copyContent` (originele `configuration.content`, voor clipboard). Update copy button om `copyContent` te gebruiken

## Files owned (exclusief)

- `Sources/HermesMac/Features/Chat/CodeBlockView.swift` (bron, wordt verplaatst)
- `Sources/HermesMac/DesignSystem/CodeBlockView.swift` (bestemming)
- `Sources/HermesMac/DesignSystem/MarkdownTheme.swift`

## Acceptatiecriteria

- CodeBlockView.swift leeft in `DesignSystem/` directory
- Oude locatie bestaat niet meer
- Copy button kopieert originele content inclusief trailing newlines
- Display render trimt trailing newlines zoals voorheen
- MarkdownTheme.swift compileert correct
