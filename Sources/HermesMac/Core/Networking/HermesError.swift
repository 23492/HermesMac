import Foundation

public enum HermesError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case notAuthenticated
    case httpStatus(code: Int, body: String?)
    case decoding(String)
    case streamEndedUnexpectedly
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
        case .transport(let detail):
            "Netwerkfout: \(detail)"
        }
    }
}
