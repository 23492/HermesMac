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
