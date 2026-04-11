import Testing
import Foundation
@testable import HermesMac

@Suite("SSELineStream")
struct SSEParserTests {

    // MARK: - Helpers

    /// Builds an `SSELineStream` from a single piece of text by splitting it
    /// into lines using `\n`, matching what `URLSession.bytes.lines` produces
    /// from a real stream. `omittingEmptySubsequences: false` preserves the
    /// blank lines that delimit SSE events.
    private func stream(from text: String) -> SSELineStream<AsyncLineSequence> {
        SSELineStream(lines: AsyncLineSequence(
            lines: text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        ))
    }

    /// Builds an `SSELineStream` directly from an array of lines. Use this
    /// when you care about exact line framing (e.g. testing CRLF tolerance or
    /// missing-trailing-blank-line EOF behaviour) and do not want to go via
    /// `String.split`.
    private func stream(fromLines lines: [String]) -> SSELineStream<AsyncLineSequence> {
        SSELineStream(lines: AsyncLineSequence(lines: lines))
    }

    /// Collects all events from a stream into an array. Centralises the
    /// boilerplate so the tests stay focused on inputs/expectations.
    private func collect(_ stream: SSELineStream<AsyncLineSequence>) async throws -> [SSEEvent] {
        var events: [SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    // MARK: - Core parser behaviour

    @Test("single event with data line")
    func singleEvent() async throws {
        let events = try await collect(stream(from: "data: hello\n\n"))
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
    }

    @Test("multiple events separated by blank lines")
    func multipleEvents() async throws {
        let input = "data: first\n\ndata: second\n\ndata: third\n\n"
        let events = try await collect(stream(from: input))
        #expect(events.count == 3)
        #expect(events.map(\.data) == ["first", "second", "third"])
    }

    @Test("comment lines are ignored")
    func commentsIgnored() async throws {
        let input = ": heartbeat\ndata: real data\n\n: another comment\ndata: more data\n\n"
        let events = try await collect(stream(from: input))
        #expect(events.count == 2)
        #expect(events.map(\.data) == ["real data", "more data"])
    }

    @Test("multi-line data joined with newlines")
    func multiLineData() async throws {
        let input = "data: line 1\ndata: line 2\ndata: line 3\n\n"
        let events = try await collect(stream(from: input))
        #expect(events.count == 1)
        #expect(events[0].data == "line 1\nline 2\nline 3")
    }

    @Test("[DONE] sentinel flagged via isDone")
    func doneSentinel() async throws {
        let input = "data: {\"content\":\"hi\"}\n\ndata: [DONE]\n\n"
        let events = try await collect(stream(from: input))
        #expect(events.count == 2)
        #expect(events[0].isDone == false)
        #expect(events[1].isDone == true)
    }

    @Test("event field captured when present")
    func eventField() async throws {
        let input = "event: message\ndata: hello\n\n"
        let events = try await collect(stream(from: input))
        #expect(events.count == 1)
        #expect(events[0].event == "message")
        #expect(events[0].data == "hello")
    }

    @Test("leading space after colon is stripped")
    func leadingSpaceStripped() async throws {
        let input = "data: value with leading space\ndata:value without space\n\n"
        let events = try await collect(stream(from: input))
        #expect(events.count == 1)
        #expect(events[0].data == "value with leading space\nvalue without space")
    }

    // MARK: - Regression tests (M1, M2, M3, L3)

    /// M1: When multiple fully-formed frames sit in the same buffer, they
    /// must come out of the parser in the same order they went in. Regression
    /// guard against a hypothetical future change that, for example, batches
    /// pending events and accidentally reverses them.
    @Test("frame ordering preserved when multiple frames in one buffer")
    func frameOrderingPreserved() async throws {
        let input = """
        data: alpha

        data: bravo

        data: charlie

        data: delta


        """
        let events = try await collect(stream(from: input))
        #expect(events.count == 4)
        #expect(events.map(\.data) == ["alpha", "bravo", "charlie", "delta"])
    }

    /// M2: Cloudflare's edge occasionally serves SSE with `\r\n` line endings.
    /// `URLSession.bytes.lines` strips the `\n` but leaves the trailing `\r`,
    /// which the parser must tolerate so the frame body is not polluted with
    /// stray carriage returns.
    @Test("CRLF line endings are tolerated")
    func crlfTolerated() async throws {
        // Simulate what bytes.lines produces on a CRLF stream: the lines
        // themselves still have a trailing `\r`.
        let lines = [
            "data: hello\r",
            "\r",
            "data: world\r",
            "\r"
        ]
        let events = try await collect(stream(fromLines: lines))
        #expect(events.count == 2)
        #expect(events.map(\.data) == ["hello", "world"])
    }

    /// M3: If the backend closes the connection without a final blank line,
    /// the last accumulated frame must still be delivered on EOF. The SSE
    /// spec says EOF implies "dispatch".
    @Test("final frame without trailing blank line is emitted on EOF")
    func finalFrameEmittedOnEOF() async throws {
        // Note: no trailing empty line.
        let lines = [
            "data: finished"
        ]
        let events = try await collect(stream(fromLines: lines))
        #expect(events.count == 1)
        #expect(events[0].data == "finished")
    }

    /// M3 addendum: EOF after a complete event followed by a partial one
    /// must emit both events without losing the partial one.
    @Test("EOF after complete frame plus partial frame emits both")
    func eofAfterCompleteAndPartial() async throws {
        let lines = [
            "data: first",
            "",
            "data: second-no-blank"
        ]
        let events = try await collect(stream(fromLines: lines))
        #expect(events.count == 2)
        #expect(events.map(\.data) == ["first", "second-no-blank"])
    }

    /// L3: Fieldless SSE lines that start with `:` are comments used for
    /// keep-alive heartbeats and must be ignored without disturbing any
    /// event that happens to be accumulating.
    @Test("fieldless comment line does not interrupt accumulating event")
    func commentBetweenDataLines() async throws {
        let input = """
        data: line 1
        : heartbeat
        data: line 2

        """
        let events = try await collect(stream(from: input))
        #expect(events.count == 1)
        #expect(events[0].data == "line 1\nline 2")
    }

    /// L3 addendum: a lone `data` field with no colon at all is valid SSE
    /// and should append an empty string to the pending data buffer.
    @Test("bare `data` line without colon appends empty value")
    func bareDataLineWithoutColon() async throws {
        let lines = [
            "data",
            ""
        ]
        let events = try await collect(stream(fromLines: lines))
        #expect(events.count == 1)
        #expect(events[0].data == "")
    }
}

/// Test helper — wraps a static array of strings as an AsyncSequence of
/// lines. Models what `URLSession.bytes.lines` produces from a real stream.
struct AsyncLineSequence: AsyncSequence, Sendable {
    typealias Element = String
    let lines: [String]

    func makeAsyncIterator() -> Iterator {
        Iterator(lines: lines)
    }

    struct Iterator: AsyncIteratorProtocol {
        let lines: [String]
        var index = 0

        mutating func next() async throws -> String? {
            guard index < lines.count else { return nil }
            defer { index += 1 }
            return lines[index]
        }
    }
}

/// Test helper — wraps a `Data` blob as an `AsyncSequence<UInt8>`, modelling
/// what `URLSession.AsyncBytes` produces from a real HTTP byte stream.
struct AsyncByteSequence: AsyncSequence, Sendable {
    typealias Element = UInt8
    let bytes: [UInt8]

    init(_ data: Data) {
        self.bytes = Array(data)
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(bytes: bytes)
    }

    struct Iterator: AsyncIteratorProtocol {
        let bytes: [UInt8]
        var index = 0

        mutating func next() async throws -> UInt8? {
            guard index < bytes.count else { return nil }
            defer { index += 1 }
            return bytes[index]
        }
    }
}

/// Regression tests for ``SSEByteLineSequence`` — the splitter that we feed
/// the raw URLSession byte stream into instead of `bytes.lines`. The whole
/// point of this type is that it *does* preserve empty lines, which
/// `AsyncLineSequence` does not. These tests pin that contract in place.
@Suite("SSEByteLineSequence")
struct SSEByteLineSequenceTests {

    private func collect(_ text: String) async throws -> [String] {
        let sequence = SSEByteLineSequence(bytes: AsyncByteSequence(Data(text.utf8)))
        var lines: [String] = []
        for try await line in sequence {
            lines.append(line)
        }
        return lines
    }

    @Test("preserves empty lines between two frames")
    func preservesEmptyLines() async throws {
        let lines = try await collect("data: first\n\ndata: second\n\n")
        #expect(lines == ["data: first", "", "data: second", ""])
    }

    @Test("strips trailing CR on CRLF streams")
    func stripsTrailingCR() async throws {
        let lines = try await collect("data: first\r\n\r\ndata: second\r\n\r\n")
        #expect(lines == ["data: first", "", "data: second", ""])
    }

    @Test("emits final line without trailing newline on EOF")
    func trailingLineWithoutNewline() async throws {
        let lines = try await collect("data: finished")
        #expect(lines == ["data: finished"])
    }

    @Test("handles an empty input without emitting anything")
    func emptyInput() async throws {
        let lines = try await collect("")
        #expect(lines == [])
    }

    @Test("tolerates multi-byte UTF-8 content across bytes")
    func multiByteUTF8() async throws {
        // "💻 hello" — the code-point 💻 is four UTF-8 bytes, so the
        // per-byte loop must not split mid-code-point.
        let lines = try await collect("data: 💻 hello\n\n")
        #expect(lines == ["data: 💻 hello", ""])
    }
}
