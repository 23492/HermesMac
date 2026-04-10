import Foundation

/// Transforms an async sequence of text lines into parsed `SSEEvent`s.
///
/// Use with `URLSession.bytes(for:).0.lines`:
/// ```swift
/// let (bytes, _) = try await session.bytes(for: request)
/// for try await event in SSELineStream(lines: bytes.lines) {
///     if event.isDone { break }
///     // decode event.data as JSON
/// }
/// ```
public struct SSELineStream<Base: AsyncSequence & Sendable>: AsyncSequence, Sendable
    where Base.Element == String {

    public typealias Element = SSEEvent

    private let base: Base

    public init(lines: Base) {
        self.base = lines
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private var pendingData: [String] = []
        private var pendingEvent: String?
        private var pendingId: String?

        init(base: Base.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> SSEEvent? {
            while let line = try await base.next() {
                // Empty line → dispatch accumulated event (if any)
                if line.isEmpty {
                    if !pendingData.isEmpty {
                        let event = SSEEvent(
                            data: pendingData.joined(separator: "\n"),
                            event: pendingEvent,
                            id: pendingId
                        )
                        reset()
                        return event
                    }
                    // Empty line with no pending data: heartbeat separator, continue
                    continue
                }

                // Comment: starts with ':' — ignore
                if line.hasPrefix(":") {
                    continue
                }

                // Field parsing
                if let colonIndex = line.firstIndex(of: ":") {
                    let field = String(line[..<colonIndex])
                    var value = String(line[line.index(after: colonIndex)...])
                    // SSE spec: one leading space after the colon is stripped
                    if value.hasPrefix(" ") {
                        value = String(value.dropFirst())
                    }

                    switch field {
                    case "data":
                        pendingData.append(value)
                    case "event":
                        pendingEvent = value
                    case "id":
                        pendingId = value
                    case "retry":
                        // Not supported; ignore
                        break
                    default:
                        // Unknown field: ignore per spec
                        break
                    }
                } else {
                    // Line without colon: treat entire line as field name with empty value
                    // per SSE spec. For data field this means "append empty string".
                    if line == "data" {
                        pendingData.append("")
                    }
                    // Other fieldless lines: ignore
                }
            }

            // End of stream — flush any pending event
            if !pendingData.isEmpty {
                let event = SSEEvent(
                    data: pendingData.joined(separator: "\n"),
                    event: pendingEvent,
                    id: pendingId
                )
                reset()
                return event
            }

            return nil
        }

        private mutating func reset() {
            pendingData.removeAll(keepingCapacity: true)
            pendingEvent = nil
            pendingId = nil
        }
    }
}
