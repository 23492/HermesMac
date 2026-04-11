import Foundation
import Observation

/// Centralized app settings. Inject via `.environment(AppSettings.shared)`.
///
/// ## Observation
///
/// The public ``apiKey`` and ``hasValidConfiguration`` properties are backed
/// by an ``@ObservationIgnored`` cache (`_apiKey`) so every write is routed
/// through a manual `access` / `withMutation` pair. That pattern is what lets
/// `@Observable` fire SwiftUI invalidation on key entry — a plain computed
/// passthrough to ``KeychainStore`` would not, because the macro can only
/// track mutations on stored properties.
///
/// ## Thread safety
///
/// The class is `@MainActor`-isolated: callers must touch it from the main
/// actor. All write paths synchronously hit ``KeychainStore`` before
/// returning, so the in-memory cache and the Keychain item never drift.
/// Keychain errors roll the cache back to the previous value and surface
/// via ``lastKeychainError`` so UI can react.
@Observable
@MainActor
public final class AppSettings {

    /// Shared singleton used by the app shell. Tests should construct their
    /// own instance via ``init(keychain:defaults:)`` instead of touching this.
    public static let shared = AppSettings()

    // MARK: - Dependencies (excluded from observation)

    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let defaults: UserDefaults

    // MARK: - Backing storage

    /// Cached copy of the Keychain-stored API key.
    ///
    /// Marked `@ObservationIgnored` so the ``@Observable`` macro does not
    /// auto-track it. The public ``apiKey`` computed property drives
    /// observation explicitly via `access(keyPath:)` / `withMutation(keyPath:)`
    /// so SwiftUI invalidation fires on that *public* key path — which is
    /// what views actually read.
    @ObservationIgnored private var _apiKey: String

    /// The last Keychain error raised by a write path, or `nil` if the
    /// previous write succeeded. Observable so UI can surface the failure.
    public var lastKeychainError: KeychainError?

    /// Currently selected model identifier. Defaults to
    /// ``BackendConfig/defaultModel``. Persisted to `UserDefaults`.
    public var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Keys.selectedModel) }
    }

    // MARK: - API key

    /// The Hermes API key used for `Authorization: Bearer` headers.
    ///
    /// Reads return the cached value from the last successful Keychain
    /// interaction; writes trim whitespace, persist to the Keychain, and roll
    /// back the in-memory cache if persistence fails. ``lastKeychainError`` is
    /// updated on every write so callers can observe success (`nil`) or
    /// failure (a typed ``KeychainError``).
    public var apiKey: String {
        get {
            access(keyPath: \.apiKey)
            return _apiKey
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            // Fast path: identical values skip the Keychain round-trip and
            // the observation fire-and-rebuild cycle entirely.
            if trimmed == _apiKey {
                return
            }
            withMutation(keyPath: \.apiKey) {
                let previous = _apiKey
                _apiKey = trimmed
                do {
                    if trimmed.isEmpty {
                        try keychain.delete(account: Keys.apiKey)
                    } else {
                        try keychain.setString(trimmed, account: Keys.apiKey)
                    }
                    lastKeychainError = nil
                } catch let error as KeychainError {
                    // Roll the cache back so reads see the previous value and
                    // the UI reflects the real persisted state.
                    _apiKey = previous
                    lastKeychainError = error
                } catch {
                    _apiKey = previous
                    lastKeychainError = .unexpectedStatus(errSecInternalError)
                }
            }
        }
    }

    // MARK: - Derived

    /// The hardcoded backend URL. Not user-configurable.
    public var backendURL: URL {
        BackendConfig.baseURL
    }

    /// `true` when a non-empty API key is cached.
    ///
    /// Reads from the same stored cache as ``apiKey``, so observation fires
    /// on the same code path — that is what makes the `RootView` "needs
    /// configuration" banner flip live as the user types in Settings.
    public var hasValidConfiguration: Bool {
        access(keyPath: \.apiKey)
        return !_apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Init

    /// Designated entry point for the shared singleton.
    ///
    /// Delegates to ``init(keychain:defaults:)`` with the production
    /// dependencies so tests can exercise the class against an isolated
    /// `KeychainStore` (unique service) and an in-memory `UserDefaults`.
    public convenience init() {
        self.init(
            keychain: KeychainStore(service: "com.hermesmac.credentials"),
            defaults: .standard
        )
    }

    /// Dependency-injected initializer for tests.
    ///
    /// The Keychain is hit synchronously during init so ``_apiKey`` is
    /// populated before any caller can observe ``hasValidConfiguration``.
    /// A missing item (or any read error) is coerced to the empty string:
    /// the class has no sensible "unknown" state and the UI already handles
    /// the empty-key case.
    ///
    /// - Parameters:
    ///   - keychain: The Keychain store to read and write the API key in.
    ///   - defaults: The `UserDefaults` instance to persist non-secret
    ///     preferences in.
    internal init(keychain: KeychainStore, defaults: UserDefaults) {
        self.keychain = keychain
        self.defaults = defaults
        self._apiKey = keychain.getString(account: Keys.apiKey) ?? ""
        self.selectedModel = defaults.string(forKey: Keys.selectedModel)
            ?? BackendConfig.defaultModel
    }

    // MARK: - Keys

    private enum Keys {
        static let apiKey = "hermes.credentials.apiKey"
        static let selectedModel = "hermes.settings.selectedModel"
    }
}
