import Foundation

/// Transforms an async sequence of text lines into parsed ``SSEEvent``s.
///
/// The SSE spec delimits events with a *blank line*, so the underlying line
/// source **must** preserve empty lines. This rules out `URLSession.bytes(_:).lines`
/// (a.k.a. `AsyncLineSequence`), which drops consecutive newlines and would
/// cause the parser to run every event together until EOF.
///
/// For bytes coming from `URLSession`, wrap them in ``SSEByteLineSequence``
/// first:
///
/// ```swift
/// let (bytes, _) = try await session.bytes(for: request)
/// let lines = SSEByteLineSequence(bytes: bytes)
/// for try await event in SSELineStream(lines: lines) {
///     if event.isDone { break }
///     // decode event.data as JSON
/// }
/// ```
///
/// The parser is tolerant of a few quirks you will see in the wild:
///
/// - **`\r\n` line endings.** Cloudflare's edge occasionally serves SSE with
///   CRLF. We strip any trailing `\r` defensively before interpreting the
///   line so CRLF streams parse cleanly.
/// - **Missing trailing blank line.** A server that closes the connection
///   without emitting a final empty line is still supposed to have its last
///   event delivered (per the SSE spec, EOF implies "dispatch"). We honour
///   that so that partial responses are not silently dropped.
/// - **Fieldless comment lines.** Lines starting with `:` are comments per
///   the spec (used for keep-alive heartbeats) and are ignored.
/// - **Fieldless non-data lines.** A bare line like `retry` (no colon) is
///   treated as a field with an empty value per the spec. We only act on
///   `data` in that form; others are ignored.
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
        /// `true` once we have drained the base sequence and emitted any
        /// trailing event on EOF. Prevents the EOF-flush code path from
        /// firing twice and returning a duplicate event.
        private var didFlushOnEOF = false

        init(base: Base.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> SSEEvent? {
            while let rawLine = try await base.next() {
                // Tolerate CRLF: a CRLF stream presents each line with a
                // trailing `\r` after `\n` has been consumed as the delimiter.
                let line = rawLine.hasSuffix("\r")
                    ? String(rawLine.dropLast())
                    : rawLine

                // Empty line → dispatch accumulated event (if any).
                if line.isEmpty {
                    if !pendingData.isEmpty {
                        let event = makeEvent()
                        reset()
                        return event
                    }
                    // Empty line with no pending data: heartbeat separator.
                    continue
                }

                // Comment: starts with `:` — ignore per SSE spec. These are
                // typically `: keep-alive` style heartbeats.
                if line.hasPrefix(":") {
                    continue
                }

                // Field parsing. Per the SSE spec, a line of the form
                // `<field>:<value>` assigns value to field, and the first
                // space after the colon is stripped if present.
                if let colonIndex = line.firstIndex(of: ":") {
                    let field = String(line[..<colonIndex])
                    var value = String(line[line.index(after: colonIndex)...])
                    if value.hasPrefix(" ") {
                        value = String(value.dropFirst())
                    }
                    apply(field: field, value: value)
                } else {
                    // Line without colon: treat the whole line as a field
                    // name with empty value per the SSE spec. We only care
                    // about `data`; other fieldless lines are ignored.
                    if line == "data" {
                        pendingData.append("")
                    }
                }
            }

            // End of stream — flush any pending event exactly once. Some
            // backends close the connection without a trailing blank line
            // and the SSE spec says EOF implies "dispatch".
            if !didFlushOnEOF, !pendingData.isEmpty {
                didFlushOnEOF = true
                let event = makeEvent()
                reset()
                return event
            }

            return nil
        }

        // MARK: - Helpers

        private mutating func apply(field: String, value: String) {
            switch field {
            case "data":
                pendingData.append(value)
            case "event":
                pendingEvent = value
            case "id":
                pendingId = value
            case "retry":
                // Not supported; ignore.
                break
            default:
                // Unknown field: ignore per spec.
                break
            }
        }

        private func makeEvent() -> SSEEvent {
            SSEEvent(
                data: pendingData.joined(separator: "\n"),
                event: pendingEvent,
                id: pendingId
            )
        }

        private mutating func reset() {
            pendingData.removeAll(keepingCapacity: true)
            pendingEvent = nil
            pendingId = nil
        }
    }
}

// MARK: - Byte → line splitter that preserves empty lines

/// Splits an async sequence of UTF-8 bytes into lines, **preserving empty
/// lines** between consecutive newlines.
///
/// We need this because `URLSession.AsyncBytes.lines` (i.e.
/// `AsyncLineSequence`) collapses consecutive newlines and therefore hides
/// the blank-line delimiters that SSE uses to frame events. Feeding the raw
/// byte stream through this splitter gives the SSE parser the event
/// boundaries it requires.
///
/// The splitter treats both `\n` and `\r\n` as line terminators. A trailing
/// partial line (i.e. bytes after the last newline before EOF) is emitted
/// on end-of-stream so no data is lost.
public struct SSEByteLineSequence<Base: AsyncSequence & Sendable>: AsyncSequence, Sendable
    where Base.Element == UInt8 {

    public typealias Element = String

    private let base: Base

    public init(bytes: Base) {
        self.base = bytes
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private var buffer: [UInt8] = []
        private var didEmitTrailingLine = false

        init(base: Base.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> String? {
            while let byte = try await base.next() {
                if byte == 0x0A { // '\n'
                    let line = consumeBufferedLine()
                    buffer.removeAll(keepingCapacity: true)
                    return line
                }
                buffer.append(byte)
            }

            // EOF. Emit whatever remains in the buffer as a final line, but
            // only once. This matches the behaviour of readLine-style APIs
            // that still return the last line if it lacks a trailing newline.
            if !didEmitTrailingLine, !buffer.isEmpty {
                didEmitTrailingLine = true
                let line = consumeBufferedLine()
                buffer.removeAll(keepingCapacity: true)
                return line
            }

            return nil
        }

        /// Returns the current buffer as a String. If the last byte is `\r`
        /// (CRLF case) it is dropped — the SSE parser will also tolerate a
        /// trailing `\r`, but doing it here means downstream consumers see
        /// a clean `\n`-delimited line regardless of the wire format.
        private func consumeBufferedLine() -> String {
            var slice = buffer[...]
            if slice.last == 0x0D { // '\r'
                slice = slice.dropLast()
            }
            return String(decoding: slice, as: UTF8.self)
        }
    }
}
