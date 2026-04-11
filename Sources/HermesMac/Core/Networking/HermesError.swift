import Foundation

/// Errors produced by the Hermes networking layer.
///
/// All cases are user-visible via ``errorDescription`` in Dutch. Keep the
/// switch in ``errorDescription`` exhaustive: when you add a case, make sure
/// there is a Dutch message for it.
public enum HermesError: Error, LocalizedError, Sendable, Equatable {
    /// The configured backend URL is malformed or unusable.
    case invalidURL

    /// No endpoint (API key / base URL) is configured.
    case notAuthenticated

    /// Backend returned a non-2xx HTTP status. `body` is the first ~4 KB of
    /// the response body (best-effort UTF-8 decoded) so the user and logs can
    /// see what went wrong. `nil` if the body could not be captured.
    case httpStatus(code: Int, body: String?)

    /// The response could not be decoded to the expected shape.
    case decoding(String)

    /// The SSE stream terminated before a `finish_reason` or `[DONE]`.
    case streamEndedUnexpectedly

    /// Backend sent a structured `{"error": {...}}` frame inside an otherwise
    /// healthy SSE stream. Carries the user-facing message from the backend.
    case inStream(String)

    /// Underlying transport failure (URLError, DNS, TLS, ...). The string is a
    /// best-effort description — prefer reading the original `URLError.Code`
    /// when you have it via `unwrapURLError()`.
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "De ingestelde backend URL is ongeldig."
        case .notAuthenticated:
            "Geen API key ingesteld. Ga naar Instellingen."
        case .httpStatus(let code, let body):
            if code == 401 {
                "Ongeldige API key (401)."
            } else if let body, !body.isEmpty {
                "HTTP \(code): \(body.prefix(200))"
            } else {
                "HTTP \(code)"
            }
        case .decoding(let detail):
            "Kon antwoord niet lezen: \(detail)"
        case .streamEndedUnexpectedly:
            "De verbinding viel onverwacht weg."
        case .inStream(let message):
            "Server fout tijdens stream: \(message)"
        case .transport(let detail):
            "Netwerkfout: \(detail)"
        }
    }
}
