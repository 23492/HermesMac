import Testing
import Foundation
@testable import HermesMac

/// `KeychainStore` tests. Each test uses a unique service identifier so the
/// suite is hermetic even when run in parallel or against a dirty local
/// Keychain. Every test cleans up its own items via `defer { try? store.delete }`
/// so a failure halfway through does not leak state into subsequent runs.
///
/// All tests construct their store with `useDataProtectionKeychain = false`.
/// That bypasses the sandboxed data protection keychain (which requires the
/// app to carry a Keychain Sharing entitlement) and lets the tests run under
/// a plain `swift test` CLI invocation. Production code uses the default
/// (`true`) via the public `init(service:)`.
@Suite("KeychainStore")
struct KeychainStoreTests {

    /// Unique service identifier for a single test case.
    private static func uniqueService(_ label: String = #function) -> String {
        "com.hermesmac.tests.\(label).\(UUID().uuidString)"
    }

    /// Creates a store that bypasses the data protection keychain so
    /// `swift test` can run without app entitlements.
    private static func makeStore(_ label: String = #function) -> KeychainStore {
        KeychainStore(
            service: uniqueService(label),
            useDataProtectionKeychain: false
        )
    }

    // MARK: - Core round-trips

    @Test("write then read returns the same value")
    func writeAndRead() throws {
        let store = Self.makeStore()
        let account = "testAccount"
        defer { try? store.delete(account: account) }

        try store.setString("hello", account: account)
        #expect(store.getString(account: account) == "hello")
    }

    @Test("overwrite replaces the value")
    func overwrite() throws {
        let store = Self.makeStore()
        let account = "testAccount"
        defer { try? store.delete(account: account) }

        try store.setString("first", account: account)
        try store.setString("second", account: account)
        #expect(store.getString(account: account) == "second")
    }

    @Test("delete removes the value")
    func deleteRemovesValue() throws {
        let store = Self.makeStore()
        let account = "testAccount"

        try store.setString("gone soon", account: account)
        try store.delete(account: account)
        #expect(store.getString(account: account) == nil)
    }

    @Test("missing item returns nil from getString")
    func missingItemReturnsNil() {
        let store = Self.makeStore()
        #expect(store.getString(account: "nonexistent") == nil)
    }

    // MARK: - Throwing read

    @Test("getStringOrThrow throws itemNotFound for missing item")
    func getStringOrThrowMissing() {
        let store = Self.makeStore()
        #expect(throws: KeychainError.itemNotFound) {
            _ = try store.getStringOrThrow(account: "nonexistent")
        }
    }

    @Test("getStringOrThrow returns the value when the item exists")
    func getStringOrThrowExisting() throws {
        let store = Self.makeStore()
        let account = "testAccount"
        defer { try? store.delete(account: account) }

        try store.setString("present", account: account)
        #expect(try store.getStringOrThrow(account: account) == "present")
    }

    // MARK: - Delete hygiene

    @Test("deleting a missing item is a no-op")
    func deleteMissingIsNoop() {
        let store = Self.makeStore()
        #expect(throws: Never.self) {
            try store.delete(account: "never-written")
        }
    }

    // MARK: - Special characters

    @Test("special characters round-trip unchanged")
    func specialCharacters() throws {
        let store = Self.makeStore()
        let account = "testAccount"
        defer { try? store.delete(account: account) }

        let secret = "!@#$%^&*()_+-={}[]|\\:;\"'<>,.?/~` éíøµç你好🔐"
        try store.setString(secret, account: account)
        #expect(store.getString(account: account) == secret)
    }

    // MARK: - Service isolation

    @Test("two stores with different services do not see each other's items")
    func serviceIsolation() throws {
        let storeA = KeychainStore(
            service: Self.uniqueService("A"),
            useDataProtectionKeychain: false
        )
        let storeB = KeychainStore(
            service: Self.uniqueService("B"),
            useDataProtectionKeychain: false
        )
        let account = "sharedAccount"
        defer {
            try? storeA.delete(account: account)
            try? storeB.delete(account: account)
        }

        try storeA.setString("a-secret", account: account)
        try storeB.setString("b-secret", account: account)

        #expect(storeA.getString(account: account) == "a-secret")
        #expect(storeB.getString(account: account) == "b-secret")

        try storeA.delete(account: account)
        #expect(storeA.getString(account: account) == nil)
        #expect(storeB.getString(account: account) == "b-secret")
    }

    // MARK: - Empty string semantics

    /// Writing an empty string is supported and round-trips as an empty
    /// string. The "ensure absent" flow is expressed via ``delete(account:)``
    /// instead. This test documents that contract: empty-string writes do
    /// *not* delete the item, they write a zero-length value.
    @Test("writing empty string stores a zero-length value")
    func emptyStringStoresZeroLength() throws {
        let store = Self.makeStore()
        let account = "testAccount"
        defer { try? store.delete(account: account) }

        try store.setString("", account: account)
        #expect(store.getString(account: account) == "")
    }

    // MARK: - KeychainError description

    @Test("KeychainError description is non-empty for each case")
    func errorDescription() {
        let cases: [KeychainError] = [
            .itemNotFound,
            .interactionNotAllowed,
            .missingEntitlement,
            .unexpectedStatus(errSecAuthFailed)
        ]
        for error in cases {
            #expect(!error.description.isEmpty)
        }
    }
}
