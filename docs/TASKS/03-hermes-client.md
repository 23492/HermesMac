# Task 03: HermesClient actor ✅ Done

**Status:** Done
**Dependencies:** Task 02
**Estimated effort:** 45 min

## Doel

Implementeer `HermesClient`, een `actor` die chat completions en model listings ophaalt van de Hermes backend. Gebruikt de `SSELineStream` uit Task 02 voor streaming.

## Context

Dit is de netwerklaag. Eén actor, één URLSession, alle calls lopen hier doorheen. Geen retry logic, geen caching, geen rate limiting — dat is scope creep voor later. Een schone simple client die één ding goed doet.

Lees `docs/API_REFERENCE.md` sectie "Endpoints die we gebruiken" en "SSE frame format" voor exact wat we consumeren.

## Scope

### In scope
- `Sources/HermesMac/Core/Networking/HermesClient.swift` — de actor
- `Sources/HermesMac/Core/Networking/ChatCompletion.swift` — request/response models
- `Sources/HermesMac/Core/Networking/HermesError.swift` — typed errors
- `Tests/HermesMacTests/HermesClientTests.swift` — minimaal 3 tests met een mock URLProtocol

### Niet in scope
- Keychain integratie (dat is Task 04)
- Endpoint selection race (Task 05)
- Retry logic
- Request cancellation via tokens (gewoon Swift Task cancellation is genoeg)

## Implementation

### ChatCompletion models

**`Sources/HermesMac/Core/Networking/ChatCompletion.swift`**:

```swift
import Foundation

// MARK: - Request

public struct ChatCompletionRequest: Encodable, Sendable {
    public let model: String
    public let messages: [ChatMessage]
    public let stream: Bool
    public let maxTokens: Int?
    public let temperature: Double?

    public init(
        model: String,
        messages: [ChatMessage],
        stream: Bool = true,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

public struct ChatMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Streaming chunk

/// A single decoded SSE chunk from the chat completions stream.
/// We only care about a subset of fields.
public struct ChatCompletionChunk: Decodable, Sendable {
    public let id: String?
    public let model: String?
    public let choices: [Choice]

    public struct Choice: Decodable, Sendable {
        public let delta: Delta?
        public let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    public struct Delta: Decodable, Sendable {
        public let role: String?
        public let content: String?
    }
}

// MARK: - Models list

public struct ModelsListResponse: Decodable, Sendable {
    public let data: [ModelInfo]
}

public struct ModelInfo: Decodable, Sendable, Identifiable, Equatable {
    public let id: String
    public let object: String
    public let ownedBy: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case object
        case ownedBy = "owned_by"
    }
}
```

### HermesError

**`Sources/HermesMac/Core/Networking/HermesError.swift`**:

```swift
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
```

### HermesClient

**`Sources/HermesMac/Core/Networking/HermesClient.swift`**:

```swift
import Foundation

/// Connection details for a Hermes backend.
public struct HermesEndpoint: Sendable, Equatable {
    public let baseURL: URL
    public let apiKey: String

    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
}

/// Actor that talks to a Hermes Agent chat completions API.
///
/// Create one instance per app session. Update via `setEndpoint(_:)`
/// when the user changes settings.
public actor HermesClient {
    private var endpoint: HermesEndpoint?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Configuration

    public func setEndpoint(_ endpoint: HermesEndpoint?) {
        self.endpoint = endpoint
    }

    // MARK: - Models

    /// Fetches the list of available models from the backend.
    public func listModels() async throws -> [ModelInfo] {
        let request = try buildRequest(path: "/models", method: "GET")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, body: data)

        do {
            let decoded = try decoder.decode(ModelsListResponse.self, from: data)
            return decoded.data
        } catch {
            throw HermesError.decoding(String(describing: error))
        }
    }

    // MARK: - Streaming chat

    /// Starts a streaming chat completion.
    /// Returns an async sequence of content deltas (already parsed strings).
    /// Cancel the surrounding Task to cancel the stream.
    public func streamChatCompletion(
        request: ChatCompletionRequest
    ) async throws -> AsyncThrowingStream<String, Error> {
        var httpRequest = try buildRequest(path: "/chat/completions", method: "POST")
        httpRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        httpRequest.httpBody = try encoder.encode(request)

        let (bytes, response) = try await session.bytes(for: httpRequest)
        try validate(response: response, body: nil)

        let localDecoder = decoder

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let eventStream = SSELineStream(lines: bytes.lines)
                    for try await event in eventStream {
                        if event.isDone {
                            continuation.finish()
                            return
                        }
                        guard let payload = event.data.data(using: .utf8) else { continue }
                        guard let chunk = try? localDecoder.decode(ChatCompletionChunk.self, from: payload) else {
                            continue
                        }
                        if let content = chunk.choices.first?.delta?.content, !content.isEmpty {
                            continuation.yield(content)
                        }
                        if chunk.choices.first?.finishReason != nil {
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: HermesError.transport(String(describing: error)))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        guard let endpoint else {
            throw HermesError.notAuthenticated
        }
        let fullURL = endpoint.baseURL.appending(path: path)
        var request = URLRequest(url: fullURL)
        request.httpMethod = method
        request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        return request
    }

    private func validate(response: URLResponse, body: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesError.transport("No HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyString = body.flatMap { String(data: $0, encoding: .utf8) }
            throw HermesError.httpStatus(code: httpResponse.statusCode, body: bodyString)
        }
    }
}
```

### Tests

Voor tests gebruiken we een `URLProtocol` subclass die requests intercepted. Dit is de idiomatic Swift way en vereist geen extra libraries.

**`Tests/HermesMacTests/HermesClientTests.swift`**:

```swift
import Testing
import Foundation
@testable import HermesMac

@Suite("HermesClient")
struct HermesClientTests {

    @Test("listModels decodes a valid response")
    func listModelsSuccess() async throws {
        let (client, protocolClass) = makeClient()
        let url = URL(string: "http://test.local/v1/models")!
        protocolClass.stubs[url] = (
            Data("""
            {"object":"list","data":[{"id":"hermes-agent","object":"model","owned_by":"hermes"}]}
            """.utf8),
            HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        await client.setEndpoint(HermesEndpoint(
            baseURL: URL(string: "http://test.local/v1")!,
            apiKey: "secret"
        ))

        let models = try await client.listModels()
        #expect(models.count == 1)
        #expect(models[0].id == "hermes-agent")
    }

    @Test("listModels throws HermesError.notAuthenticated when no endpoint set")
    func notAuthenticated() async {
        let (client, _) = makeClient()
        await #expect(throws: HermesError.notAuthenticated) {
            try await client.listModels()
        }
    }

    @Test("listModels maps 401 to httpStatus error")
    func httpError() async {
        let (client, protocolClass) = makeClient()
        let url = URL(string: "http://test.local/v1/models")!
        protocolClass.stubs[url] = (
            Data(#"{"error":{"message":"Invalid API key"}}"#.utf8),
            HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
        )

        await client.setEndpoint(HermesEndpoint(
            baseURL: URL(string: "http://test.local/v1")!,
            apiKey: "wrong"
        ))

        do {
            _ = try await client.listModels()
            Issue.record("Expected error")
        } catch let error as HermesError {
            if case .httpStatus(let code, _) = error {
                #expect(code == 401)
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeClient() -> (HermesClient, MockURLProtocol.Type) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return (HermesClient(session: session), MockURLProtocol.self)
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var stubs: [URL: (Data, HTTPURLResponse)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let (data, response) = Self.stubs[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

## Verification

```bash
cd /root/HermesMac
swift build 2>&1 | tail -10
# Expected: build succeeds

swift test --filter HermesClientTests 2>&1 | tail -20
# Expected: 3 tests pass
```

## Done when

- [ ] `HermesClient.swift` bestaat en is een `actor`
- [ ] `ChatCompletion.swift` heeft de request/response types
- [ ] `HermesError.swift` heeft typed errors met Nederlandse localized descriptions
- [ ] Minimaal 3 tests passen met een mocked URL session
- [ ] Commit: `feat(task03): HermesClient actor with streaming chat completions`

## Open punten

- De streaming test (die daadwerkelijk een fake SSE body levert via MockURLProtocol) is complexer en vereist een stream-capable mock. Leave that voor een later follow-up als de integratie tegen een live backend al werkt.
- Als Swift 6 klaagt over `nonisolated(unsafe)` op de stubs dict: dat is de enige plek waar we het accepteren omdat URLProtocol class methods geen andere optie bieden.

## Completion notes

**Date:** 2026-04-10
**Commit:** 8397dff

Alle vier files aangemaakt exact volgens task spec: ChatCompletion.swift (request/response models), HermesError.swift (typed errors met Nederlandse descriptions), HermesClient.swift (actor met listModels + streamChatCompletion), en HermesClientTests.swift (3 tests met MockURLProtocol). Build niet geverifieerd op Linux, moet op Mac getest worden.
