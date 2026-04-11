# Task 21: settings and keychain hardening

**Status:** Niet gestart
**Dependencies:** Task 17 (error states — shipped)
**Estimated effort:** 60–90 min

## Doel

`AppSettings` echt `@Observable`-compliant maken, Keychain errors expliciet maken, `BackendConfig` force-unwrap-vrij, en accessibility van de API key opslag aangescherpt naar `WhenUnlockedThisDeviceOnly`.

## Context

Code review van 2026-04-11 leverde in Settings/Keychain 3 High, 6 Medium en 3 Low findings op. De H1 fix (stored property + didSet) unblockt meteen App-shell H4: `RootView.needsConfigurationState` updatet nu live zodra de user een key intikt in Settings.

Deze task loopt **parallel** met Tasks 19–20, 22–24. Alleen files in `Core/Settings/` en `Tests/HermesMacTests/KeychainStoreTests.swift` zijn van deze agent.

## Scope

### In scope

**High**
- **H1** — `AppSettings.swift`: `apiKey` is nu een computed property die rechtstreeks door-delegeert naar `KeychainStore`. Dat betekent dat `@Observable` geen notifier afvuurt, want er is geen stored property die verandert. Refactor naar `@ObservationIgnored private var _apiKey: String?` + computed getter die `_apiKey` teruggeeft + setter die `_apiKey` updatet (triggert observation) en schrijft naar Keychain. Initialiseer `_apiKey` in de init door een synchrone read uit Keychain.
- **H2** — `AppSettings.swift`: `try? keychain.setData(...)` slikt de error. Voeg `var lastKeychainError: KeychainError?` (observable) toe, catch de error, roll back de state (oude waarde van `_apiKey`), en zet `lastKeychainError`. De SettingsView (die van Task 23 is) kan dit later oppakken via zijn eigen error binding — voeg hier alleen de property toe.
- **H4** — `BackendConfig.swift`: `static let baseURL = URL(string: "...")!` is een force-unwrap. Vervang door `URL(string:)` in een `static let` initializer met `preconditionFailure("Invalid baseURL literal")` in de else branch. Zie CLAUDE.md regel: geen force unwraps in productiecode.
- **H-Keychain** — `KeychainStore.swift`: verander `kSecAttrAccessible` van `kSecAttrAccessibleAfterFirstUnlock` naar `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Voeg `kSecAttrSynchronizable as String: false` toe. Voeg `kSecUseDataProtectionKeychain as String: true` toe — check wel of entitlements al `keychain-access-groups` bevatten of niet; als niet, commenteer dat deze key vereist dat Xcode's Keychain Sharing/Data Protection entitlement aanstaat en laat de `true` staan (is het veilige default op macOS 10.15+ / iOS 8+).

**Medium**
- **M1** — `KeychainStore.setData`: refactor naar delete-then-add (SecItemDelete, check status, SecItemAdd) voor attribute-hygiene. Gebruik geen `SecItemUpdate` want dat kan attributes achterlaten die niet matchen met de `kSecAttrAccessible` hierboven.
- **M3** — `KeychainStore.swift`: breidt `KeychainError` uit met named cases: `case itemNotFound`, `case interactionNotAllowed`, `case missingEntitlement`, `case unexpectedStatus(OSStatus)`. Implementeer `CustomStringConvertible` die `SecCopyErrorMessageString(status, nil)` gebruikt voor een leesbare beschrijving.
- **M4** — `KeychainStore.swift`: voeg `func getStringOrThrow(account: String) throws -> String` toe (naast de bestaande `getString(...) -> String?`), zodat callers die een key vereisen een expliciete fout krijgen.
- **M5** — `AppSettings.swift`: `hasValidConfiguration` en `setAPIKey(_:)` moeten whitespace trimmen (`.trimmingCharacters(in: .whitespacesAndNewlines)`) voordat ze checken/opslaan.
- **M6** — `AppSettings.swift`: voeg een `internal init(keychain: KeychainStore, defaults: UserDefaults)` toe voor dependency injection in tests. Public `init()` blijft bestaan en roept de internal aan met `KeychainStore()` en `.standard`.
- **M-Tests** — `KeychainStoreTests.swift`: voeg tests toe voor delete-missing-item (moet noop zijn), special characters (`!@#$%^&*()` in token), service isolation (twee stores met andere service moeten elkaar niet zien), empty-string semantics (leeg item opslaan moet throwen of item verwijderen, documenteer welke). Gebruik `defer { try? store.delete(account: ...) }` voor cleanup.

**Low**
- **L1** — `AppSettings.swift`: rename UserDefaults en Keychain keys naar `"hermes.credentials.apiKey"` en `"hermes.settings.selectedModel"`. Safe: pre-release, geen migratie.
- **L3** — `KeychainStore.swift`: DocC note dat de struct `Sendable` is omdat hij stateless is en alle state via Security framework gaat.

### Niet in scope

- **SettingsView.swift** — Task 23 terrein (incl. runTest cancellation en error pattern matching).
- **AppSettings write path surfacing in UI** — Task 23 doet dit.
- **Force-unwrap fixes buiten Settings** — andere tasks.
- **Files**: alles buiten `Core/Settings/*` en `Tests/HermesMacTests/KeychainStoreTests.swift`.

## Implementation

### Files to modify

- `Sources/HermesMac/Core/Settings/AppSettings.swift`
- `Sources/HermesMac/Core/Settings/KeychainStore.swift`
- `Sources/HermesMac/Core/Settings/BackendConfig.swift`
- `Tests/HermesMacTests/KeychainStoreTests.swift`

### Approach

**AppSettings.swift** (abbreviated):

```swift
@Observable
public final class AppSettings {
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let defaults: UserDefaults

    private var _apiKey: String?
    public var lastKeychainError: KeychainError?
    public var selectedModel: String

    public var apiKey: String? {
        get { _apiKey }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let previous = _apiKey
            _apiKey = trimmed
            do {
                if let trimmed, !trimmed.isEmpty {
                    try keychain.setString(trimmed, account: Keys.apiKey)
                } else {
                    try keychain.delete(account: Keys.apiKey)
                }
                lastKeychainError = nil
            } catch let kcError as KeychainError {
                _apiKey = previous
                lastKeychainError = kcError
            } catch {
                _apiKey = previous
                lastKeychainError = .unexpectedStatus(-1)
            }
        }
    }

    public convenience init() {
        self.init(keychain: KeychainStore(), defaults: .standard)
    }

    internal init(keychain: KeychainStore, defaults: UserDefaults) {
        self.keychain = keychain
        self.defaults = defaults
        self._apiKey = try? keychain.getString(account: Keys.apiKey)
        self.selectedModel = defaults.string(forKey: Keys.selectedModel) ?? "gpt-4o-mini"
    }

    public var hasValidConfiguration: Bool {
        guard let trimmed = _apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !trimmed.isEmpty
    }

    private enum Keys {
        static let apiKey = "hermes.credentials.apiKey"
        static let selectedModel = "hermes.settings.selectedModel"
    }
}
```

**KeychainStore.swift** query block shape voor `setData`:

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    kSecAttrSynchronizable as String: false,
    kSecUseDataProtectionKeychain as String: true,
    kSecValueData as String: data,
]
SecItemDelete(query as CFDictionary)
let addStatus = SecItemAdd(query as CFDictionary, nil)
guard addStatus == errSecSuccess else {
    throw KeychainError.from(status: addStatus)
}
```

## Verification

```
cd /Users/kiranknoppert/Documents/HermesMac/.claude/worktrees/task21-settings-keychain
swift build 2>&1 | tail -20
swift test --filter KeychainStoreTests 2>&1 | tail -30
```

Expected: build zonder warnings. KeychainStore tests slagen (de oude plus de nieuwe). Nieuwe M-tests slagen voor delete-missing, special chars, service isolation, empty string.

## Done when

- [ ] All High findings addressed (H1, H2, H4, H-Keychain).
- [ ] All Medium findings addressed or logged to `99-followups.md`.
- [ ] Low findings addressed.
- [ ] Nieuwe tests toegevoegd en slagen.
- [ ] `swift build` passes without warnings.
- [ ] `swift test` passes (specifieke failures gedocumenteerd).
- [ ] Self-review tegen de 6 /review skill categorieën — met bijzondere aandacht voor Security (Keychain accessibility, geen logging van secrets) en Swift Best Practices (`@Observable` invalidation).
- [ ] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [ ] Conventional commit `fix(task21): settings and keychain hardening` op branch `fix/task21-settings-keychain`, met `file:line` referenties in body.
- [ ] Branch gepusht naar `origin`.
