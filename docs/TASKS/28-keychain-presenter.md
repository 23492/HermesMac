# Task 28: KeychainError Dutch presenter (#16)

**Status:** Open
**Branch:** `fix/task28-keychain-presenter`
**Followup:** #16

## Doel

Voeg Nederlandse user-facing foutmeldingen toe voor KeychainError in SettingsView.

## Wat te doen

1. Voeg private helper `localizedKeychainError(_ error: KeychainStore.KeychainError) -> String` toe die elke case mapt naar een Nederlandse user-facing string
2. Gebruik het overal waar `lastKeychainError` getoond wordt in de settings UI
3. Houd `KeychainStore` zelf locale-neutraal (geen wijzigingen daar)

## Files owned (exclusief)

- `Sources/HermesMac/Features/SettingsPane/SettingsView.swift`

## Acceptatiecriteria

- Elke `KeychainError` case heeft een Nederlandse user-facing string
- `KeychainStore` is onveranderd
- Settings UI toont Nederlandse meldingen in plaats van Engelse descriptions
