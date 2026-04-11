import Foundation

/// Hardcoded backend configuration. The app always talks to this URL.
///
/// If the backend URL ever changes, edit this file — it is intentionally not a
/// user setting. Architecture decision recorded in `docs/ARCHITECTURE.md`.
public enum BackendConfig {
    /// The string literal the ``baseURL`` is built from. Kept as a constant so
    /// the error message in ``makeBaseURL()`` can reference the exact literal
    /// that failed to parse.
    private static let baseURLString = "https://hermes-api.knoppsmart.com/v1"

    /// The one and only Hermes backend URL.
    ///
    /// Computed via ``makeBaseURL()`` so any typo in ``baseURLString`` crashes
    /// the app early with a descriptive `preconditionFailure` instead of a
    /// silent force-unwrap.
    public static let baseURL: URL = makeBaseURL()

    /// Default model identifier used when creating a new conversation.
    public static let defaultModel = "hermes-agent"

    /// Parses ``baseURLString`` into a `URL`, failing fast with a descriptive
    /// message if the literal is malformed.
    ///
    /// Using `preconditionFailure` here is preferred over force-unwrapping:
    /// the crash message points at the exact offending string so debug builds
    /// surface the bug loudly, while release builds still trap on the same
    /// line.
    private static func makeBaseURL() -> URL {
        guard let url = URL(string: baseURLString) else {
            preconditionFailure(
                "BackendConfig.baseURLString is not a valid URL literal: \(baseURLString)"
            )
        }
        return url
    }
}
