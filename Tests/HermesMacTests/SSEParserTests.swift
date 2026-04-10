import Testing
import Foundation
@testable import HermesMac

@Suite("SSELineStream")
struct SSEParserTests {

    // Helper: make an SSELineStream from a static string
    private func stream(from text: String) -> SSELineStream<AsyncLineSequence> {
        SSELineStream(lines: AsyncLineSequence(
            lines: text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        ))
    }

    @Test("single event with data line")
    func singleEvent() async throws {
        let input = "data: hello\n\n"
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
    }

    @Test("multiple events separated by blank lines")
    func multipleEvents() async throws {
        let input = "data: first\n\ndata: second\n\ndata: third\n\n"
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 3)
        #expect(events.map(\.data) == ["first", "second", "third"])
    }

    @Test("comment lines are ignored")
    func commentsIgnored() async throws {
        let input = ": heartbeat\ndata: real data\n\n: another comment\ndata: more data\n\n"
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 2)
        #expect(events.map(\.data) == ["real data", "more data"])
    }

    @Test("multi-line data joined with newlines")
    func multiLineData() async throws {
        let input = "data: line 1\ndata: line 2\ndata: line 3\n\n"
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0].data == "line 1\nline 2\nline 3")
    }

    @Test("[DONE] sentinel flagged via isDone")
    func doneSentinel() async throws {
        let input = "data: {\"content\":\"hi\"}\n\ndata: [DONE]\n\n"
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 2)
        #expect(events[0].isDone == false)
        #expect(events[1].isDone == true)
    }

    @Test("event field captured when present")
    func eventField() async throws {
        let input = "event: message\ndata: hello\n\n"
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0].event == "message")
        #expect(events[0].data == "hello")
    }

    @Test("leading space after colon is stripped")
    func leadingSpaceStripped() async throws {
        let input = "data: value with leading space\ndata:value without space\n\n"
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0].data == "value with leading space\nvalue without space")
    }
}

/// Test helper — wraps a static array of strings as an AsyncSequence of lines.
/// Models what `URLSession.bytes.lines` produces from a real stream.
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
