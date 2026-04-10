# Task 02: SSE line parser

**Status:** Niet gestart
**Dependencies:** Task 00
**Estimated effort:** 45 min

## Doel

Implementeer een robuuste Server-Sent Events parser die werkt met `URLSession.bytes` en de SSE frames van de Hermes backend correct interpreteert. Volledig unit-tested.

## Context

Dit is de hartader van de streaming chat. De oude HermesApp had een byte-per-byte parser die UTF-8 brak en SSE comments niet afhandelde. We doen het nu correct vanaf de eerste regel.

Lees `docs/API_REFERENCE.md` sectie "SSE frame format" voor de exacte observaties uit een live backend call. Belangrijke punten:

- Elke event is één of meer `data: ...` lines gevolgd door een lege regel
- `data: [DONE]` markeert einde van de stream
- SSE comments beginnen met `:` en moeten genegeerd worden (heartbeats!)
- Geen `event: ...` headers in deze backend (alleen anonymous events)

## Scope

### In scope
- `Sources/HermesMac/Core/Networking/SSEEvent.swift` — struct die één event representeert
- `Sources/HermesMac/Core/Networking/SSELineStream.swift` — async sequence die `URLSession.bytes` converteert naar `SSEEvent`s
- `Tests/HermesMacTests/SSEParserTests.swift` — minimaal 6 tests die alle edge cases dekken

### Niet in scope
- JSON decoding van de `data:` field (dat gebeurt in HermesClient in task 03)
- HTTP request logic
- Error recovery (dat is de caller's verantwoordelijkheid)

## Implementation

### Background: SSE spec samengevat

Een SSE stream bestaat uit events gescheiden door lege regels. Elke regel heeft een van deze vormen:

```
field: value
```

Velden die wij gebruiken:
- `data:` — de payload, accumuleert bij multi-line
- `event:` — event type (niet gebruikt door deze backend maar we moeten het wel correct parsen als het komt)
- `id:` — event ID (niet gebruikt)
- `retry:` — retry timeout in ms (niet gebruikt)

Regels die beginnen met `:` zijn comments en moeten genegeerd worden.

Een event is compleet wanneer je een lege regel tegenkomt. Dan yield je de accumulated event en reset je voor de volgende.

### SSEEvent struct

**`Sources/HermesMac/Core/Networking/SSEEvent.swift`**:

```swift
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
```

### SSELineStream

**`Sources/HermesMac/Core/Networking/SSELineStream.swift`**:

```swift
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
    where Base.Element == String, Base: Sendable {

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
```

### Tests

**`Tests/HermesMacTests/SSEParserTests.swift`**:

```swift
import Testing
import Foundation
@testable import HermesMac

@Suite("SSELineStream")
struct SSEParserTests {

    // Helper: make an SSELineStream from a static string
    private func stream(from text: String) -> SSELineStream<AsyncLineSequence> {
        SSELineStream(lines: AsyncLineSequence(lines: text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)))
    }

    @Test("single event with data line")
    func singleEvent() async throws {
        let input = """
        data: hello

        """
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0].data == "hello")
    }

    @Test("multiple events separated by blank lines")
    func multipleEvents() async throws {
        let input = """
        data: first

        data: second

        data: third

        """
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 3)
        #expect(events.map(\.data) == ["first", "second", "third"])
    }

    @Test("comment lines are ignored")
    func commentsIgnored() async throws {
        let input = """
        : heartbeat
        data: real data

        : another comment
        data: more data

        """
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 2)
        #expect(events.map(\.data) == ["real data", "more data"])
    }

    @Test("multi-line data joined with newlines")
    func multiLineData() async throws {
        let input = """
        data: line 1
        data: line 2
        data: line 3

        """
        var events: [SSEEvent] = []
        for try await event in stream(from: input) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0].data == "line 1\nline 2\nline 3")
    }

    @Test("[DONE] sentinel flagged via isDone")
    func doneSentinel() async throws {
        let input = """
        data: {"content":"hi"}

        data: [DONE]

        """
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
        let input = """
        event: message
        data: hello

        """
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
        let input = """
        data: value with leading space
        data:value without space

        """
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
        var lines: [String]
        var index = 0

        mutating func next() async throws -> String? {
            guard index < lines.count else { return nil }
            defer { index += 1 }
            return lines[index]
        }
    }
}
```

## Verification

```bash
cd /root/HermesMac
swift build 2>&1 | tail -10
# Expected: Build complete.

swift test --filter SSEParserTests 2>&1 | tail -20
# Expected: All 7 tests pass.
```

## Done when

- [ ] `SSEEvent.swift` en `SSELineStream.swift` bestaan
- [ ] `SSEParserTests.swift` heeft minimaal 7 tests die allemaal passen
- [ ] Comments (`:` prefix) worden correct genegeerd
- [ ] Multi-line data wordt correct geconcateneerd met `\n`
- [ ] `[DONE]` wordt herkend via `isDone`
- [ ] Commit: `feat(task02): SSE line parser with comment and multi-line support`

## Open punten

- Als je tegen het probleem aanloopt dat `AsyncLineSequence` als test helper niet werkt onder strict concurrency, markeer hem als `Sendable` en maak de `Iterator` struct properties `var` maar de hele sequence `let`. Dat is een bekende Swift 6 papercut.
