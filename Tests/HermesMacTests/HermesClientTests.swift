import Testing
import Foundation
@testable import HermesMac

/// We run these serially because ``MockURLProtocol`` uses a shared static
/// stub registry. Making the suite serial is simpler and clearer than
/// inventing per-test URL namespaces.
@Suite("HermesClient", .serialized)
struct HermesClientTests {

    init() {
        // Isolate tests from one another by wiping the shared stub state
        // before each test body runs. `init()` fires per test case because
        // the suite is a struct, so this is effectively a setUp hook.
        MockURLProtocol.reset()
    }

    // MARK: - listModels

    @Test("listModels decodes a valid response")
    func listModelsSuccess() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/models")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200),
            body: Data("""
            {"object":"list","data":[{"id":"hermes-agent","object":"model","owned_by":"hermes"}]}
            """.utf8)
        )

        await client.setEndpoint(HermesEndpoint(
            baseURL: URL(string: "http://test.local/v1")!,
            apiKey: "secret"
        ))

        let models = try await client.listModels()
        #expect(models.count == 1)
        #expect(models[0].id == "hermes-agent")
        #expect(models[0].ownedBy == "hermes")
    }

    @Test("listModels throws HermesError.notAuthenticated when no endpoint set")
    func notAuthenticated() async {
        let client = makeClient()
        await #expect(throws: HermesError.notAuthenticated) {
            try await client.listModels()
        }
    }

    @Test("listModels maps 401 to httpStatus error with body")
    func httpError401() async {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/models")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 401),
            body: Data(#"{"error":{"message":"Invalid API key"}}"#.utf8)
        )

        await client.setEndpoint(HermesEndpoint(
            baseURL: URL(string: "http://test.local/v1")!,
            apiKey: "wrong"
        ))

        do {
            _ = try await client.listModels()
            Issue.record("Expected error")
        } catch let error as HermesError {
            if case .httpStatus(let code, let body) = error {
                #expect(code == 401)
                #expect(body?.contains("Invalid API key") == true)
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - streamChatCompletion (H4)

    @Test("streaming happy path yields a single delta frame")
    func streamingHappyPath() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200, contentType: "text/event-stream"),
            body: Self.sseBody([
                #"{"id":"1","choices":[{"delta":{"content":"Hi"},"finish_reason":null}]}"#
            ])
        )
        await client.setEndpoint(Self.testEndpoint())

        let stream = try await client.streamChatCompletion(request: Self.testRequest())
        var collected: [String] = []
        for try await piece in stream {
            collected.append(piece)
        }
        #expect(collected == ["Hi"])
    }

    @Test("streaming stops at [DONE] sentinel without emitting it as content")
    func streamingDoneSentinel() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200, contentType: "text/event-stream"),
            body: Self.sseBody([
                #"{"id":"1","choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}"#,
                "[DONE]",
                // Anything after [DONE] must be ignored.
                #"{"id":"1","choices":[{"delta":{"content":"ignored"},"finish_reason":null}]}"#
            ])
        )
        await client.setEndpoint(Self.testEndpoint())

        let stream = try await client.streamChatCompletion(request: Self.testRequest())
        var collected: [String] = []
        for try await piece in stream {
            collected.append(piece)
        }
        #expect(collected == ["Hello"])
    }

    @Test("streaming stops on finish_reason: \"stop\"")
    func streamingFinishReasonStop() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200, contentType: "text/event-stream"),
            body: Self.sseBody([
                #"{"id":"1","choices":[{"delta":{"content":"done"},"finish_reason":null}]}"#,
                #"{"id":"1","choices":[{"delta":{},"finish_reason":"stop"}]}"#,
                // After finish_reason we must not emit further content.
                #"{"id":"1","choices":[{"delta":{"content":"ghost"},"finish_reason":null}]}"#
            ])
        )
        await client.setEndpoint(Self.testEndpoint())

        let stream = try await client.streamChatCompletion(request: Self.testRequest())
        var collected: [String] = []
        for try await piece in stream {
            collected.append(piece)
        }
        #expect(collected == ["done"])
    }

    /// C1 regression: a cooperative `Task.cancel()` used to come back as
    /// ``HermesError/transport(_:)``, making a clean cancel look like a
    /// network failure. We verify that however the cancel lands — clean
    /// end-of-stream, ``CancellationError``, or `URLError(.cancelled)` — it
    /// never falsely surfaces as transport.
    @Test("streaming cancellation never surfaces as a HermesError.transport")
    func streamingCancellationDoesNotLeakAsTransport() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200, contentType: "text/event-stream"),
            body: Self.sseBody([
                #"{"id":"1","choices":[{"delta":{"content":"slow"},"finish_reason":null}]}"#
            ]),
            deliveryDelay: 0.25
        )
        await client.setEndpoint(Self.testEndpoint())

        let outerTask = Task { () -> Result<[String], Error> in
            do {
                let stream = try await client.streamChatCompletion(request: Self.testRequest())
                var collected: [String] = []
                for try await piece in stream { collected.append(piece) }
                return .success(collected)
            } catch {
                return .failure(error)
            }
        }

        try? await Task.sleep(nanoseconds: 20_000_000)
        outerTask.cancel()

        switch await outerTask.value {
        case .success:
            break // Cancel landed cleanly — acceptable.
        case .failure(let error):
            Self.expectCleanCancellation(error)
        }
    }

    /// C1 regression addendum: when the outer Task is already cancelled
    /// before we hit URLSession, the initial `session.bytes(for:)` either
    /// throws ``CancellationError`` or `URLError(.cancelled)`. Either way
    /// the client must propagate it as-is.
    @Test("streaming CancellationError is re-thrown, not wrapped, at request time")
    func streamingCancellationAtRequestTime() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200, contentType: "text/event-stream"),
            body: Self.sseBody([
                #"{"id":"1","choices":[{"delta":{"content":"hi"},"finish_reason":null}]}"#
            ])
        )
        await client.setEndpoint(Self.testEndpoint())

        let outerTask = Task { () -> Result<Void, Error> in
            await Task.yield() // Let the enclosing .cancel() land first.
            do {
                _ = try await client.streamChatCompletion(request: Self.testRequest())
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        outerTask.cancel()

        switch await outerTask.value {
        case .success:
            break // Request beat the cancel — inconclusive but not a failure.
        case .failure(let error):
            Self.expectCleanCancellation(error)
        }
    }

    @Test("streaming surfaces in-stream {error:{...}} as HermesError.inStream")
    func streamingInStreamError() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200, contentType: "text/event-stream"),
            body: Self.sseBody([
                #"{"id":"1","choices":[{"delta":{"content":"partial"},"finish_reason":null}]}"#,
                #"{"error":{"message":"rate limited","type":"rate_limit","code":"rate_limit_exceeded"}}"#
            ])
        )
        await client.setEndpoint(Self.testEndpoint())

        let stream = try await client.streamChatCompletion(request: Self.testRequest())
        var collected: [String] = []
        do {
            for try await piece in stream {
                collected.append(piece)
            }
            Issue.record("Expected in-stream error")
        } catch let error as HermesError {
            if case .inStream(let message) = error {
                #expect(message == "rate limited")
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
        // Partial content received before the error should still have been
        // yielded to the caller so the UI can keep what it had.
        #expect(collected == ["partial"])
    }

    @Test("streaming 401 throws httpStatus(401, body) with drained body")
    func streaming401() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 401),
            body: Data(#"{"error":{"message":"Invalid API key","type":"invalid_request_error"}}"#.utf8)
        )
        await client.setEndpoint(Self.testEndpoint(apiKey: "wrong"))

        do {
            _ = try await client.streamChatCompletion(request: Self.testRequest())
            Issue.record("Expected 401 error")
        } catch let error as HermesError {
            if case .httpStatus(let code, let body) = error {
                #expect(code == 401)
                #expect(body?.contains("Invalid API key") == true)
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("streaming decode failure surfaces as HermesError.decoding, not silent drop")
    func streamingDecodeFailure() async throws {
        let client = makeClient()
        let url = URL(string: "http://test.local/v1/chat/completions")!
        MockURLProtocol.stub(
            url: url,
            response: Self.httpResponse(url: url, status: 200, contentType: "text/event-stream"),
            body: Self.sseBody([
                // Not valid JSON at all.
                "this is not json"
            ])
        )
        await client.setEndpoint(Self.testEndpoint())

        let stream = try await client.streamChatCompletion(request: Self.testRequest())
        do {
            for try await _ in stream {}
            Issue.record("Expected decoding error")
        } catch let error as HermesError {
            if case .decoding = error {
                // Expected.
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - HermesEndpoint.description

    @Test("HermesEndpoint description redacts the API key")
    func endpointDescriptionRedacted() {
        let endpoint = HermesEndpoint(
            baseURL: URL(string: "https://hermes-api.knoppsmart.com/v1")!,
            apiKey: "secret-key-should-not-leak"
        )
        let description = String(describing: endpoint)
        #expect(description.contains("hermes-api.knoppsmart.com"))
        #expect(description.contains("<redacted>"))
        #expect(description.contains("secret-key-should-not-leak") == false)
    }

    // MARK: - Helpers

    private func makeClient() -> HermesClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return HermesClient(session: session)
    }

    private static func testEndpoint(apiKey: String = "secret") -> HermesEndpoint {
        HermesEndpoint(
            baseURL: URL(string: "http://test.local/v1")!,
            apiKey: apiKey
        )
    }

    private static func testRequest() -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: "hermes-agent",
            messages: [ChatMessage(role: "user", content: "hi")],
            stream: true
        )
    }

    private static func httpResponse(
        url: URL,
        status: Int,
        contentType: String = "application/json"
    ) -> HTTPURLResponse {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        ) else {
            // This never fails in practice — HTTPURLResponse only returns nil
            // for invalid inputs, and our inputs are always valid.
            fatalError("Failed to build HTTPURLResponse for \(url) / \(status)")
        }
        return response
    }

    /// Builds a byte body that looks like an SSE stream, with one `data:`
    /// frame per input string separated by blank lines.
    private static func sseBody(_ frames: [String]) -> Data {
        Data(frames.map { "data: \($0)\n\n" }.joined().utf8)
    }

    /// Asserts that `error` is a "clean" cancellation — i.e. either a
    /// ``CancellationError``, a `URLError(.cancelled)`, or any ``HermesError``
    /// that is **not** ``HermesError/transport(_:)``. Used by the two C1
    /// regression tests.
    private static func expectCleanCancellation(_ error: Error) {
        if error is CancellationError { return }
        if let urlError = error as? URLError, urlError.code == .cancelled { return }
        if let hermes = error as? HermesError {
            if case .transport = hermes {
                Issue.record("Cancellation must not surface as HermesError.transport")
            } else {
                Issue.record("Cancellation surfaced as unexpected HermesError: \(hermes)")
            }
            return
        }
        Issue.record("Cancellation surfaced as unexpected error: \(error)")
    }
}
