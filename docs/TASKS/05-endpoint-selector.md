# Task 05: EndpointSelector with race logic

**Status:** Niet gestart
**Dependencies:** Task 03, Task 04
**Estimated effort:** 30 min

## Doel

Implementeer een `EndpointSelector` die automatisch kiest tussen de primary (Cloudflare Tunnel) en local URL door een snelle race te doen naar `/models`. De winnaar wordt 30 seconden gecached.

## Context

Lees `docs/CLOUDFLARE_TUNNEL.md` sectie "Dual-endpoint strategie in de client" voor de exacte gedragsomschrijving. Samengevat:

- Bij het starten van een chat sessie: race beide URLs parallel met 500ms timeout
- Eerste 200 wint
- Cache de keuze voor 30 seconden
- Als alleen primary is ingesteld: skip de race
- Als beide falen: gooi een error

## Scope

### In scope
- `Sources/HermesMac/Core/Networking/EndpointSelector.swift` — de actor
- `Tests/HermesMacTests/EndpointSelectorTests.swift` — 3-4 tests met MockURLProtocol

### Niet in scope
- Automatic failover mid-stream (te complex voor v1; user moet refreshen)
- Preference persistence ("ik koos deze URL, gebruik die altijd")
- Health check background task

## Implementation

```swift
import Foundation

/// Picks which Hermes endpoint to use based on a quick race between primary and local URLs.
public actor EndpointSelector {

    public struct Selection: Sendable, Equatable {
        public let endpoint: HermesEndpoint
        public let isLocal: Bool
    }

    private let session: URLSession
    private var cachedSelection: Selection?
    private var cacheExpiresAt: Date?

    /// How long a selection stays cached before we re-race.
    private static let cacheDuration: TimeInterval = 30

    /// Per-probe timeout.
    private static let probeTimeout: TimeInterval = 0.5

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Returns the best endpoint to use right now.
    /// Races primary and local if both are provided.
    public func pick(
        primary: HermesEndpoint,
        local: HermesEndpoint?
    ) async throws -> Selection {
        // Use cache if valid
        if let cached = cachedSelection, let expiry = cacheExpiresAt, expiry > Date() {
            return cached
        }

        let selection = try await race(primary: primary, local: local)
        cachedSelection = selection
        cacheExpiresAt = Date().addingTimeInterval(Self.cacheDuration)
        return selection
    }

    /// Clears the cache forcing a re-race on next pick.
    public func invalidate() {
        cachedSelection = nil
        cacheExpiresAt = nil
    }

    // MARK: - Private

    private func race(primary: HermesEndpoint, local: HermesEndpoint?) async throws -> Selection {
        guard let local else {
            // No local configured: just verify primary reachable
            try await probe(primary)
            return Selection(endpoint: primary, isLocal: false)
        }

        // Race them
        return try await withThrowingTaskGroup(of: Selection.self) { group in
            group.addTask {
                try await self.probe(local)
                return Selection(endpoint: local, isLocal: true)
            }
            group.addTask {
                try await self.probe(primary)
                return Selection(endpoint: primary, isLocal: false)
            }

            // Take first success
            for try await result in group {
                group.cancelAll()
                return result
            }

            throw HermesError.transport("Beide endpoints zijn onbereikbaar")
        }
    }

    private func probe(_ endpoint: HermesEndpoint) async throws {
        let url = endpoint.baseURL.appending(path: "/models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Self.probeTimeout

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HermesError.transport("probe failed")
        }
    }
}
```

## Tests

```swift
import Testing
import Foundation
@testable import HermesMac

@Suite("EndpointSelector")
struct EndpointSelectorTests {

    @Test("picks primary when only primary is configured")
    func primaryOnly() async throws {
        let (selector, protocolClass) = makeSelector()
        let url = URL(string: "http://primary.test/v1/models")!
        protocolClass.stubs[url] = (Data("{\"object\":\"list\",\"data\":[]}".utf8),
                                     HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let primary = HermesEndpoint(baseURL: URL(string: "http://primary.test/v1")!, apiKey: "k")
        let selection = try await selector.pick(primary: primary, local: nil)
        #expect(selection.isLocal == false)
        #expect(selection.endpoint.baseURL.absoluteString == "http://primary.test/v1")
    }

    @Test("cache hit returns same selection within cache window")
    func cacheHit() async throws {
        let (selector, protocolClass) = makeSelector()
        let url = URL(string: "http://primary.test/v1/models")!
        protocolClass.stubs[url] = (Data("{\"object\":\"list\",\"data\":[]}".utf8),
                                     HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let primary = HermesEndpoint(baseURL: URL(string: "http://primary.test/v1")!, apiKey: "k")
        let first = try await selector.pick(primary: primary, local: nil)

        // Remove the stub — second call should still work via cache
        protocolClass.stubs.removeAll()
        let second = try await selector.pick(primary: primary, local: nil)
        #expect(first == second)
    }

    @Test("invalidate clears cache")
    func invalidateClearsCache() async throws {
        let (selector, protocolClass) = makeSelector()
        let url = URL(string: "http://primary.test/v1/models")!
        protocolClass.stubs[url] = (Data("{\"object\":\"list\",\"data\":[]}".utf8),
                                     HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)

        let primary = HermesEndpoint(baseURL: URL(string: "http://primary.test/v1")!, apiKey: "k")
        _ = try await selector.pick(primary: primary, local: nil)
        await selector.invalidate()
        protocolClass.stubs.removeAll()

        // Without cache and without stub: should fail
        await #expect(throws: Error.self) {
            _ = try await selector.pick(primary: primary, local: nil)
        }
    }

    private func makeSelector() -> (EndpointSelector, MockURLProtocol.Type) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return (EndpointSelector(session: session), MockURLProtocol.self)
    }
}
```

MockURLProtocol komt uit Task 03. Hergebruik.

## Verification

```bash
swift test --filter EndpointSelectorTests 2>&1 | tail -15
# Expected: 3 tests pass
```

## Done when

- [ ] `EndpointSelector.swift` bestaat als actor
- [ ] 30 seconden cache werkt
- [ ] Race logic skipt correct als alleen primary is geconfigureerd
- [ ] Tests passen
- [ ] Commit: `feat(task05): EndpointSelector with dual-URL race and caching`
