# Task 04: AppSettings + KeychainStore

**Status:** Niet gestart
**Dependencies:** Task 00
**Estimated effort:** 25 min

## Doel

Persistente app settings. De backend URL is hardcoded (zie `BackendConfig` verderop). Alleen de API key is user-input en moet in Keychain.

## Context

De app moet onthouden:
- API key (in Keychain, NIET in UserDefaults)
- Welk model de laatste keer is gebruikt (UserDefaults is prima)

De backend URL is niet user-configurable. Hardcoded naar `https://hermes-api.knoppsmart.com/v1`. Als die ooit verandert is dat een code change.

## Scope

### In scope
- `Sources/HermesMac/Core/Settings/KeychainStore.swift` — thin wrapper om Security.framework
- `Sources/HermesMac/Core/Settings/BackendConfig.swift` — constant hardcoded URL
- `Sources/HermesMac/Core/Settings/AppSettings.swift` — `@Observable` class, singleton entry via environment
- `Tests/HermesMacTests/KeychainStoreTests.swift` — basic write/read/delete test

### Niet in scope
- Settings UI (dat is task 15)
- Sync tussen devices
- Versioned settings migration
- User-configurable backend URL

## Implementation

### BackendConfig

**`Sources/HermesMac/Core/Settings/BackendConfig.swift`**:

```swift
import Foundation

/// Hardcoded backend configuration. The app always talks to this URL.
///
/// If the backend URL ever changes, edit this file — it's not a setting.
public enum BackendConfig {
    /// The one and only Hermes backend URL.
    public static let baseURL = URL(string: "https://hermes-api.knoppsmart.com/v1")!

    /// Default model to use when creating a new conversation.
    public static let defaultModel = "hermes-agent"
}
```

### KeychainStore

Simpel Security framework wrapper. Vermijdt third-party libs.

**`Sources/HermesMac/Core/Settings/KeychainStore.swift`**:

```swift
import Foundation
import Security

/// Thin wrapper around the system Keychain for storing string secrets.
///
/// Each instance is scoped to a service name (e.g. "com.hermesmac.apikey").
/// Keys within a service are distinct strings.
public struct KeychainStore: Sendable {
    public let service: String

    public init(service: String) {
        self.service = service
    }

    /// Writes a value for the given key. Overwrites existing entries.
    public func setString(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        try setData(data, forKey: key)
    }

    /// Reads a string value for the given key, or `nil` if missing.
    public func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes the value for the given key. No-op if absent.
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Private

    private func setData(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Try update first
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            // Add new
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    private func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}

public enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}
```

### AppSettings

**`Sources/HermesMac/Core/Settings/AppSettings.swift`**:

```swift
import Foundation
import Observation

/// Centralized app settings. Inject via `.environment(AppSettings.shared)`.
@Observable
@MainActor
public final class AppSettings {

    public static let shared = AppSettings()

    // MARK: - Storage

    private let keychain = KeychainStore(service: "com.hermesmac.credentials")
    private let defaults = UserDefaults.standard

    private enum Key {
        static let apiKey = "apiKey"
        static let selectedModel = "hermes.selectedModel"
    }

    // MARK: - Public properties

    /// Currently selected model id. Defaults to `BackendConfig.defaultModel`.
    public var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Key.selectedModel) }
    }

    /// API key is stored in Keychain — never UserDefaults.
    public var apiKey: String {
        get { keychain.getString(forKey: Key.apiKey) ?? "" }
        set {
            if newValue.isEmpty {
                try? keychain.delete(forKey: Key.apiKey)
            } else {
                try? keychain.setString(newValue, forKey: Key.apiKey)
            }
        }
    }

    // MARK: - Derived

    /// The hardcoded backend URL. Not user-configurable.
    public var backendURL: URL {
        BackendConfig.baseURL
    }

    /// Whether the user has entered an API key. URL is always valid.
    public var hasValidConfiguration: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Init

    private init() {
        self.selectedModel = defaults.string(forKey: Key.selectedModel) ?? BackendConfig.defaultModel
    }
}
```

### Tests

**`Tests/HermesMacTests/KeychainStoreTests.swift`**:

```swift
import Testing
import Foundation
@testable import HermesMac

@Suite("KeychainStore")
struct KeychainStoreTests {

    @Test("write then read returns the same value")
    func writeAndRead() throws {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        let key = "testKey"
        try store.setString("hello", forKey: key)
        #expect(store.getString(forKey: key) == "hello")
        try store.delete(forKey: key)
    }

    @Test("overwrite updates the value")
    func overwrite() throws {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        let key = "testKey"
        try store.setString("first", forKey: key)
        try store.setString("second", forKey: key)
        #expect(store.getString(forKey: key) == "second")
        try store.delete(forKey: key)
    }

    @Test("delete removes the value")
    func delete() throws {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        let key = "testKey"
        try store.setString("gone soon", forKey: key)
        try store.delete(forKey: key)
        #expect(store.getString(forKey: key) == nil)
    }

    @Test("missing key returns nil")
    func missingKey() {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        #expect(store.getString(forKey: "nonexistent") == nil)
    }
}
```

## Verification

Op een Mac:
```bash
swift build
swift test --filter KeychainStoreTests
# Expected: 4 tests pass
```

Op Linux (geen Swift toolchain): review de code zorgvuldig, commit.

## Done when

- [ ] `BackendConfig.swift` bestaat met de hardcoded URL
- [ ] `KeychainStore.swift` bestaat met get/set/delete
- [ ] `AppSettings.swift` bestaat als `@Observable` singleton
- [ ] `KeychainStoreTests.swift` heeft 4 tests
- [ ] `AppSettings.backendURL` returnt de hardcoded `BackendConfig.baseURL`
- [ ] API key is in Keychain, NIET in UserDefaults
- [ ] Commit: `feat(task04): AppSettings with hardcoded backend URL and Keychain-backed API key`

## Open punten

- Op Linux werkt `SecItemAdd` niet. Tests kunnen daar niet draaien. Kiran test op zijn Mac.
