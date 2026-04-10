# Task 04: AppSettings + KeychainStore

**Status:** Niet gestart
**Dependencies:** Task 00
**Estimated effort:** 30 min

## Doel

Persistente app settings met API keys in Keychain en URLs in UserDefaults. Één centrale `AppSettings` observable klasse die de rest van de app gebruikt.

## Context

De app moet onthouden:
- Primary backend URL (default: `https://hermes-api.knoppsmart.com/v1`)
- Optional local backend URL (default: leeg)
- API key (in Keychain, NIET in UserDefaults)
- Welk model de laatste keer is gebruikt
- "Show local endpoint warning" preference (later)

De API key is gevoelig en moet in Keychain. URLs en modelvoorkeur mogen in UserDefaults.

## Scope

### In scope
- `Sources/HermesMac/Core/Settings/KeychainStore.swift` — thin wrapper om Security.framework
- `Sources/HermesMac/Core/Settings/AppSettings.swift` — `@Observable` class, singleton entry via environment
- `Tests/HermesMacTests/KeychainStoreTests.swift` — basic write/read/delete test

### Niet in scope
- Settings UI (dat is task 15)
- Sync tussen devices
- Versioned settings migration

## Implementation

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

```yaml
NOTE: dit is pseudocode, echte syntax hieronder
```

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
        static let primaryURL = "hermes.primaryURL"
        static let localURL = "hermes.localURL"
        static let apiKey = "apiKey"
        static let selectedModel = "hermes.selectedModel"
    }

    // MARK: - Defaults

    private static let defaultPrimaryURL = "https://hermes-api.knoppsmart.com/v1"
    private static let defaultModel = "hermes-agent"

    // MARK: - Public properties (observable)

    public var primaryURLString: String {
        didSet { defaults.set(primaryURLString, forKey: Key.primaryURL) }
    }

    public var localURLString: String {
        didSet { defaults.set(localURLString, forKey: Key.localURL) }
    }

    public var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Key.selectedModel) }
    }

    // API key is NOT stored in UserDefaults — always fetch from Keychain
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

    public var primaryURL: URL? {
        URL(string: primaryURLString)
    }

    public var localURL: URL? {
        localURLString.isEmpty ? nil : URL(string: localURLString)
    }

    public var hasValidConfiguration: Bool {
        primaryURL != nil && !apiKey.isEmpty
    }

    // MARK: - Init

    private init() {
        self.primaryURLString = defaults.string(forKey: Key.primaryURL) ?? Self.defaultPrimaryURL
        self.localURLString = defaults.string(forKey: Key.localURL) ?? ""
        self.selectedModel = defaults.string(forKey: Key.selectedModel) ?? Self.defaultModel
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

```bash
cd /root/HermesMac
swift build 2>&1 | tail -10

# Keychain tests only work on macOS/iOS. On Linux they will be skipped/failed.
# If running on a Mac:
swift test --filter KeychainStoreTests 2>&1 | tail -20
# Expected: 4 tests pass
```

## Done when

- [ ] `KeychainStore.swift` bestaat met get/set/delete
- [ ] `AppSettings.swift` bestaat als `@Observable` singleton
- [ ] `KeychainStoreTests.swift` heeft minimaal 4 tests
- [ ] Default primary URL is `https://hermes-api.knoppsmart.com/v1`
- [ ] API key is **niet** in UserDefaults zichtbaar
- [ ] Commit: `feat(task04): AppSettings with Keychain-backed API key`

## Open punten

- Op Linux werkt `SecItemAdd` niet. De tests hiervoor zullen daar falen. Dit is verwacht — documenteer in de completion notes dat tests alleen op macOS/iOS passen.
- In v1 is `AppSettings` een singleton. Als later blijkt dat we multiple instances willen voor testing, kan dat met een DI pattern. Voor nu: YAGNI.
