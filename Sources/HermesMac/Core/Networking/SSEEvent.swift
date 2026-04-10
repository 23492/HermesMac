import Foundation

/// Represents a single Server-Sent Event.
public struct SSEEvent: Sendable, Equatable {
    /// Raw data payload (accumulated from all `data:` lines).
    public let data: String

    /// Optional event type from `event:` field. `nil` if absent.
    public let event: String?

    /// Optional event ID from `id:` field. `nil` if absent.
    public let id: String?

    public init(data: String, event: String? = nil, id: String? = nil) {
        self.data = data
        self.event = event
        self.id = id
    }

    /// Whether this event represents the end-of-stream sentinel `[DONE]`.
    public var isDone: Bool {
        data == "[DONE]"
    }
}
