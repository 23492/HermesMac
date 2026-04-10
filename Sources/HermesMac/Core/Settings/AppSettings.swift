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
