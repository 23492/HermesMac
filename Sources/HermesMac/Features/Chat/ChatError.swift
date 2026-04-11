import Foundation

/// Categorised error state surfaced by ``ChatModel`` to the view layer.
///
/// `HermesError` is the wire-level network error type — rich but
/// noisy. `ChatError` is the product-level error type that the UI
/// reasons about: each case maps directly to a banner, a piece of
/// copy and an action button. The mapping lives in
/// ``ChatModel/categorise(_:)``.
public enum ChatError: Equatable, Sendable {
    /// No API key has been configured yet.
    case notConfigured

    /// Backend returned `401 Unauthorized`.
    case authentication

    /// Network-level failure (no connection, DNS fail, TLS error, etc.).
    /// The associated string is a short human-readable detail.
    case network(String)

    /// The SSE stream broke mid-reply. Any partial content that was
    /// already streamed remains visible in the conversation.
    case streamInterrupted

    /// Catch-all for anything else (unexpected HTTP status, decoding
    /// failure, unknown transport issue).
    case other(String)

    /// User-facing Dutch message for the banner/empty state.
    public var message: String {
        switch self {
        case .notConfigured:
            String(localized: "error.notConfigured", defaultValue: "Je hebt nog geen API key ingesteld.")
        case .authentication:
            String(localized: "error.authentication", defaultValue: "Je API key klopt niet.")
        case .network(let detail):
            String(localized: "error.network", defaultValue: "Kan backend niet bereiken: \(detail)")
        case .streamInterrupted:
            String(localized: "error.streamInterrupted", defaultValue: "Verbinding verbroken tijdens antwoord.")
        case .other(let detail):
            detail
        }
    }

    /// Whether a retry of the same request makes sense — i.e. whether
    /// the UI should offer an "Opnieuw proberen" action. Configuration
    /// problems don't get a retry button; they get an "Open Instellingen"
    /// button instead (see ``ChatError/needsSettings``).
    public var isRetryable: Bool {
        switch self {
        case .network, .streamInterrupted, .other:
            true
        case .notConfigured, .authentication:
            false
        }
    }

    /// Whether the appropriate remediation is to open Settings.
    public var needsSettings: Bool {
        switch self {
        case .notConfigured, .authentication:
            true
        case .network, .streamInterrupted, .other:
            false
        }
    }
}
