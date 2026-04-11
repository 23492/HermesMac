import Foundation
import Security

/// Thin wrapper around the system Keychain for storing string secrets.
///
/// Each instance is scoped to a service name (e.g. `"com.hermesmac.credentials"`).
/// Within a service, individual secrets are distinguished by an `account` string
/// (which maps to `kSecAttrAccount`).
///
/// ## Security posture
///
/// All items are stored with:
/// - `kSecAttrAccessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — the
///   secret is readable only while the device is unlocked, and never restored
///   to another device from a backup.
/// - `kSecAttrSynchronizable = false` — never replicated to iCloud Keychain.
/// - `kSecUseDataProtectionKeychain = true` — opt into the modern data
///   protection keychain on macOS 10.15+ / iOS 8+, which is sandboxed and
///   behaves consistently across platforms.
///
/// ## Sendability
///
/// `KeychainStore` is a value type with a single immutable `service` string
/// and carries no cached state — all reads and writes go straight through the
/// `Security` framework, which is thread-safe. The struct is therefore
/// trivially `Sendable` and can be shared across actors without synchronization.
public struct KeychainStore: Sendable {
    /// The Keychain service identifier these operations are scoped to.
    public let service: String

    /// When `true`, queries opt into the sandboxed data protection keychain
    /// (`kSecUseDataProtectionKeychain = true`). This is the default and the
    /// production security posture. Tests running without app entitlements
    /// can pass `false` to fall back to the legacy (login) keychain, which
    /// is accessible from command-line `swift test` runs.
    private let useDataProtectionKeychain: Bool

    /// Creates a store scoped to the given service identifier.
    ///
    /// The resulting store opts into the modern data protection keychain.
    /// That attribute requires the app to carry a Keychain Sharing / Data
    /// Protection entitlement when built via Xcode; a plain `swift test`
    /// CLI run has no entitlements and cannot use this store — tests should
    /// construct their own via ``init(service:useDataProtectionKeychain:)``
    /// with `false`.
    ///
    /// - Parameter service: A unique reverse-DNS string, typically shared
    ///   across the whole app (e.g. `"com.hermesmac.credentials"`).
    public init(service: String) {
        self.init(service: service, useDataProtectionKeychain: true)
    }

    /// Dependency-injection initializer for tests.
    ///
    /// The only reason to pass `useDataProtectionKeychain = false` is to run
    /// tests under the `swift test` CLI on macOS where there is no app
    /// bundle, no entitlements and therefore no access to the sandboxed
    /// keychain. Production code must always use ``init(service:)`` which
    /// defaults to `true`.
    ///
    /// - Parameters:
    ///   - service: A unique reverse-DNS string for the Keychain service.
    ///   - useDataProtectionKeychain: Whether to set
    ///     `kSecUseDataProtectionKeychain = true` on every query.
    internal init(service: String, useDataProtectionKeychain: Bool) {
        self.service = service
        self.useDataProtectionKeychain = useDataProtectionKeychain
    }

    // MARK: - Public API

    /// Writes a UTF-8 encoded string for the given account.
    ///
    /// Overwrites any existing entry for the same `(service, account)` pair.
    ///
    /// - Parameters:
    ///   - value: The secret to store. Empty strings are allowed but the
    ///     caller should usually prefer ``delete(account:)`` instead.
    ///   - account: The account identifier within this service.
    /// - Throws: ``KeychainError`` if the underlying `SecItemAdd` call fails.
    public func setString(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        try setData(data, account: account)
    }

    /// Reads a UTF-8 string for the given account, or `nil` if no item exists
    /// or the stored bytes are not valid UTF-8.
    ///
    /// This method never throws: missing items and decode failures both
    /// collapse into `nil`. Callers that need an explicit error for a missing
    /// secret should use ``getStringOrThrow(account:)`` instead.
    ///
    /// - Parameter account: The account identifier within this service.
    public func getString(account: String) -> String? {
        guard let data = try? getData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Reads a UTF-8 string for the given account and throws if the item is
    /// missing, the bytes are not valid UTF-8, or the Keychain returns any
    /// other error.
    ///
    /// - Parameter account: The account identifier within this service.
    /// - Returns: The stored string.
    /// - Throws: ``KeychainError/itemNotFound`` if no item exists,
    ///   ``KeychainError/unexpectedStatus(_:)`` for other failures.
    public func getStringOrThrow(account: String) throws -> String {
        let data = try getData(account: account)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecDecode)
        }
        return string
    }

    /// Deletes the item for the given account. Missing items are a no-op:
    /// `errSecItemNotFound` from `SecItemDelete` is intentionally swallowed
    /// so callers can write "ensure absent" flows without conditional logic.
    ///
    /// - Parameter account: The account identifier within this service.
    /// - Throws: ``KeychainError`` for any status other than success or
    ///   `errSecItemNotFound`.
    public func delete(account: String) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.from(status: status)
        }
    }

    // MARK: - Private

    /// Builds the identifying query for a `(service, account)` pair.
    ///
    /// All reads, writes and deletes start from this base so the security
    /// attributes stay consistent across the struct.
    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    /// Writes raw bytes for the given account using delete-then-add hygiene.
    ///
    /// We deliberately avoid `SecItemUpdate` here: an update could leave
    /// previously-set attributes (for example an older, weaker
    /// `kSecAttrAccessible` value) in place, which defeats the purpose of
    /// tightening the accessibility constant. Deleting first guarantees the
    /// newly-added item uses exactly the attribute set configured below.
    private func setData(_ data: Data, account: String) throws {
        // Delete any existing entry first. `errSecItemNotFound` is fine: it
        // just means there was nothing to overwrite.
        var deleteQuery = baseQuery(account: account)
        // `kSecAttrSynchronizable = false` on the delete query can fail to
        // match legacy items that were written without that attribute. Drop
        // the attribute here so `SecItemDelete` reliably removes *anything*
        // matching (service, account) before we add the new value.
        deleteQuery.removeValue(forKey: kSecAttrSynchronizable as String)
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.from(status: deleteStatus)
        }

        var addQuery = baseQuery(account: account)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        addQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.from(status: addStatus)
        }
    }

    /// Reads raw bytes for the given account, throwing a typed error instead
    /// of collapsing missing items to `nil`.
    private func getData(account: String) throws -> Data {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
        guard let data = result as? Data else {
            throw KeychainError.unexpectedStatus(errSecDecode)
        }
        return data
    }
}

// MARK: - KeychainError

/// Typed errors from Keychain operations.
///
/// Named cases cover the statuses we handle explicitly; anything else lands
/// in ``unexpectedStatus(_:)``. The ``CustomStringConvertible`` conformance
/// uses `SecCopyErrorMessageString` to turn raw `OSStatus` values into the
/// human-readable descriptions that the Security framework publishes.
public enum KeychainError: Error, Equatable, Sendable {
    /// No item was found for the requested `(service, account)` pair.
    case itemNotFound
    /// The Keychain refused the operation because the device is locked or
    /// the item requires user presence.
    case interactionNotAllowed
    /// The app is not entitled to access this Keychain item. On macOS this
    /// usually means the app is missing the Keychain access group entitlement.
    case missingEntitlement
    /// Any other `OSStatus` we do not handle specifically.
    case unexpectedStatus(OSStatus)

    /// Maps a raw `OSStatus` to the best-matching case.
    ///
    /// - Parameter status: The status returned by a `SecItem*` call.
    static func from(status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:
            return .itemNotFound
        case errSecInteractionNotAllowed:
            return .interactionNotAllowed
        case errSecMissingEntitlement:
            return .missingEntitlement
        default:
            return .unexpectedStatus(status)
        }
    }
}

extension KeychainError: CustomStringConvertible {
    public var description: String {
        let status: OSStatus
        let prefix: String
        switch self {
        case .itemNotFound:
            status = errSecItemNotFound
            prefix = "Keychain item not found"
        case .interactionNotAllowed:
            status = errSecInteractionNotAllowed
            prefix = "Keychain interaction not allowed"
        case .missingEntitlement:
            status = errSecMissingEntitlement
            prefix = "Missing Keychain entitlement"
        case .unexpectedStatus(let code):
            status = code
            prefix = "Unexpected Keychain status \(code)"
        }
        if let cfMessage = SecCopyErrorMessageString(status, nil) {
            return "\(prefix): \(cfMessage as String)"
        }
        return prefix
    }
}
