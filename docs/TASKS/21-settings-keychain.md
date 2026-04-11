# Task 21: settings and keychain hardening ✅ Done

**Status:** ✅ Done
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

- [x] All High findings addressed (H1, H2, H4, H-Keychain).
- [x] All Medium findings addressed or logged to `99-followups.md`.
- [x] Low findings addressed.
- [x] Nieuwe tests toegevoegd en slagen.
- [x] `swift build` passes without warnings.
- [x] `swift test` passes (specifieke failures gedocumenteerd).
- [x] Self-review tegen de 6 /review skill categorieën — met bijzondere aandacht voor Security (Keychain accessibility, geen logging van secrets) en Swift Best Practices (`@Observable` invalidation).
- [x] Task file header → `✅ Done` + per-finding completion notes (what/why).
- [x] Conventional commit `fix(task21): settings and keychain hardening` op branch `fix/task21-settings-keychain`, met `file:line` referenties in body.
- [x] Branch gepusht naar `origin`.

## Completion notes

**Date:** 2026-04-11
**Branch:** `fix/task21-settings-keychain`

### Per-finding summary

**H1 — AppSettings `apiKey` no longer a plain passthrough**
`Sources/HermesMac/Core/Settings/AppSettings.swift:44` adds `@ObservationIgnored
private var _apiKey: String` as the backing cache. The public `apiKey`
(`AppSettings.swift:65`) is a computed property that explicitly calls
`access(keyPath: \.apiKey)` in its getter and `withMutation(keyPath: \.apiKey)
{ ... }` in its setter. `hasValidConfiguration` (`AppSettings.swift:112`)
also calls `access(keyPath: \.apiKey)` before deriving its bool, so any
SwiftUI view that reads either property registers a dependency on the same
key path and gets invalidated on every write. That is the actual root cause
for the "RootView needs-configuration banner doesn't flip on key entry"
bug — a stored property (or, as here, a cache + manual invalidation) is
what `@Observable` needs to fire SwiftUI rebuilds.

**H2 — Keychain errors surfaced via `lastKeychainError` + rollback**
`AppSettings.swift:48` adds `public var lastKeychainError: KeychainError?`.
The `apiKey` setter (`AppSettings.swift:70-97`) captures the previous cache
value, speculatively updates `_apiKey` to the trimmed input, calls
`keychain.setString`/`keychain.delete`, and on failure rolls `_apiKey` back
to `previous` and assigns the typed error to `lastKeychainError`. Success
clears `lastKeychainError = nil`. The whole block runs inside
`withMutation(keyPath: \.apiKey)` so observation fires exactly once per
attempted write, whether it succeeded or rolled back. SettingsView (Task 23)
can observe `lastKeychainError` to surface the failure to the user.

**H4 — BackendConfig no longer force-unwraps the URL literal**
`Sources/HermesMac/Core/Settings/BackendConfig.swift:26` introduces
`makeBaseURL()` which calls `URL(string: baseURLString)` and
`preconditionFailure("BackendConfig.baseURLString is not a valid URL literal:
\(baseURLString)")` in the else branch. The string literal lives in a
dedicated private constant so the crash message includes the exact offending
text. Debug builds trap loudly, release builds still trap on the same line.

**H-Keychain — accessibility, synchronizable, data protection**
`Sources/HermesMac/Core/Settings/KeychainStore.swift:136-147` factors the
query into a `baseQuery(account:)` helper that sets
`kSecAttrSynchronizable = false` (never replicated to iCloud Keychain) and
conditionally sets `kSecUseDataProtectionKeychain = true` when the store is
configured to use the sandboxed keychain. `KeychainStore.swift:170-172` adds
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` on the add path only (reads
and deletes intentionally don't match on accessibility so they find any item
the app previously wrote). Public init `KeychainStore(service:)`
(`KeychainStore.swift:49`) always defaults `useDataProtectionKeychain = true`
so production code always gets the hardened posture.

**M1 — setData is delete-then-add**
`KeychainStore.swift:156-177` deletes the matching `(service, account)`
entry unconditionally (ignoring `errSecItemNotFound`) and then runs
`SecItemAdd` with the full attribute set. The delete query drops
`kSecAttrSynchronizable` so it matches legacy items that may have been
written without that attribute and reliably removes them. No more
`SecItemUpdate`: an update could leave stale `kSecAttrAccessible` values
in place and defeat the purpose of H-Keychain.

**M3 — Named cases + `CustomStringConvertible` via `SecCopyErrorMessageString`**
`KeychainStore.swift:207-234` adds named cases `itemNotFound`,
`interactionNotAllowed`, `missingEntitlement`, `unexpectedStatus(OSStatus)`
plus a `static func from(status:)` mapper. `KeychainStore.swift:236-259`
adds a `CustomStringConvertible` extension that composes a fixed English
prefix with the localized description from
`SecCopyErrorMessageString(status, nil)` for each case.

**M4 — `getStringOrThrow(account:)`**
`KeychainStore.swift:107-113` is a new throwing variant that calls the
private `getData(account:)` (which now throws on any non-success status),
attempts UTF-8 decode, and throws `KeychainError.unexpectedStatus(errSecDecode)`
if the bytes aren't valid UTF-8. `getString(account:)` keeps the lenient
`nil`-on-missing semantics for the `AppSettings` init path.

**M5 — Whitespace trimming**
`AppSettings.swift:71` trims in the `apiKey` setter before doing the Keychain
round-trip. `AppSettings.swift:112-114` also trims in `hasValidConfiguration`
so a string of only whitespace reads as "no config".

**M6 — Internal DI init**
`AppSettings.swift:143-149` is the new `internal init(keychain:defaults:)`.
The public `init()` (`AppSettings.swift:124-129`) convenience-delegates to
it with the production `KeychainStore(service: "com.hermesmac.credentials")`
and `UserDefaults.standard`. Tests can now inject a dedicated store/defaults
pair via `@testable import HermesMac`.

**M-Tests — new KeychainStore coverage**
`Tests/HermesMacTests/KeychainStoreTests.swift` adds:
- `deleteMissingIsNoop` — `delete(account:)` on an empty service must not
  throw (`KeychainStoreTests.swift:88`).
- `specialCharacters` — round-trips `!@#$%^&*()` plus unicode, emoji, and
  quote characters (`KeychainStoreTests.swift:97`).
- `serviceIsolation` — two stores with different service identifiers can
  coexist without seeing each other's items (`KeychainStoreTests.swift:110`).
- `emptyStringStoresZeroLength` — documents that writing `""` stores a
  zero-length value, it does NOT delete the item
  (`KeychainStoreTests.swift:139`).
- `getStringOrThrowMissing` / `getStringOrThrowExisting` — cover the new
  throwing read path (`KeychainStoreTests.swift:68`, `:76`).
- `errorDescription` — every `KeychainError` case has a non-empty
  `description` (`KeychainStoreTests.swift:151`).

All tests construct their store via
`KeychainStore(service:useDataProtectionKeychain: false)` so `swift test`
can run from the CLI without app entitlements. See the next section for
why.

**L1 — Key rename**
`AppSettings.swift:153-156` renames the UserDefaults / Keychain keys to
`"hermes.credentials.apiKey"` and `"hermes.settings.selectedModel"`.
Pre-release, no migration needed.

**L3 — `Sendable` DocC**
`KeychainStore.swift:21-26` adds a "## Sendability" section explaining why
the struct is safely `Sendable`: it holds one immutable string and forwards
every operation to the Security framework, which is itself thread-safe.

### Test-only seam for the data protection keychain

`kSecUseDataProtectionKeychain = true` requires an app bundle with a
Keychain Sharing entitlement. Plain `swift test` on macOS has no bundle
and no entitlements, so the first draft of the tests failed with
"Missing Keychain entitlement". The solution is a single internal DI
seam: `KeychainStore` now has a second, `internal init(service:
useDataProtectionKeychain:)` (`KeychainStore.swift:65`) that lets tests
opt out of the sandboxed path. The `public init(service:)`
(`KeychainStore.swift:49`) still defaults to `true` so production code
is always hardened. `baseQuery(account:)` (`KeychainStore.swift:136`)
only adds the data protection attribute when the flag is on, so the
legacy login-keychain path stays clean.

### Verification

- `swift build` — clean, no warnings.
- `swift test --filter KeychainStoreTests` — all 11 tests pass.
- `swift test` full suite — all tests in my ownership pass. There is a
  pre-existing `HermesClientTests "listModels decodes a valid response"`
  crash (uncaught NSException / signal 11) unrelated to Task 21; logged
  to `99-followups.md #3`.

### Followups added to `99-followups.md`

- `#3` — HermesClient `listModels` test crashes in `swift test` CLI runs.
- `#4` — `KeychainError.description` is English; Task 23's SettingsView
  will need a per-case Dutch presenter instead of displaying `.description`
  raw.

### Self-review against /review skill's 6 categories

1. **Swift Best Practices** — no force unwraps, no `try!`, typed `KeychainError`
   enum, `@Observable` / `@MainActor` correctly applied, `Sendable` where
   appropriate, doc comments on every public declaration, `final class`
   on `AppSettings`, `private`/`internal` access modifiers explicit.
2. **SwiftUI Quality** — the central H1 fix: `access(keyPath:)` and
   `withMutation(keyPath:)` on the public `apiKey` key path so that SwiftUI
   invalidation fires on key entry. Both `apiKey` reads and
   `hasValidConfiguration` reads register dependencies on `\.apiKey`, so
   the "needs configuration" banner flips live.
3. **Performance** — the `apiKey` setter fast-path skips the Keychain
   round-trip when the trimmed value matches the current cache. Init reads
   the Keychain synchronously once, never again on reads. `hasValidConfiguration`
   trims on every read; the string is tiny and this is negligible.
4. **Security & Safety** — production keychain items use
   `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `kSecAttrSynchronizable
   = false`, `kSecUseDataProtectionKeychain = true`. No logging anywhere
   in `Core/Settings/`; `KeychainError.description` only contains the
   OSStatus and its `SecCopyErrorMessageString` — never a secret value.
   Rollback on Keychain write failure preserves the in-memory cache and
   UI state so a failed write doesn't leave the app claiming a
   "configured" state it can't actually use.
5. **Architecture & Maintainability** — all files well under the 400-line
   smell threshold (AppSettings 157, BackendConfig 38, KeychainStore 259,
   KeychainStoreTests 173). Single responsibility per file. `internal init`
   DI seam for tests. Full DocC on every public declaration.
6. **Project-Specific (CLAUDE.md)** — Swift 6 strict concurrency clean,
   `@Observable` (not `ObservableObject`), no force unwraps, Dutch
   user-facing strings are deferred to Task 23 (noted in followup #4),
   English doc comments, Swift Testing.
