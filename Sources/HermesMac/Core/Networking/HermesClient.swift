import Foundation

/// Connection details for a Hermes backend.
///
/// Conforms to ``CustomStringConvertible`` so the endpoint can be printed or
/// logged without leaking the API key — see ``description``.
public struct HermesEndpoint: Sendable, Equatable, CustomStringConvertible {
    /// The base URL of the backend, e.g. `https://hermes-api.knoppsmart.com/v1`.
    public let baseURL: URL

    /// Bearer token used in the `Authorization` header.
    public let apiKey: String

    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    /// Logs only the host and scheme; the API key and any query string that
    /// could contain credentials are redacted. Use this instead of
    /// interpolating the raw endpoint into log output.
    public var description: String {
        let host = baseURL.host() ?? "<no-host>"
        let scheme = baseURL.scheme ?? "?"
        let path = baseURL.path()
        // Deliberately omit apiKey and any query string.
        return "HermesEndpoint(\(scheme)://\(host)\(path), apiKey: <redacted>)"
    }
}

/// Actor that talks to a Hermes Agent chat completions API.
///
/// Create one instance per call site. Pass a ``HermesEndpoint`` to each
/// method so the caller controls which backend is targeted — no shared
/// mutable state needed.
///
/// The streaming path uses `URLSession.bytes(for:)`, which requires
/// macOS 12+ / iOS 15+. Our minimum deployment target (macOS 14 / iOS 17
/// per `Package.swift`) comfortably exceeds that, but the explicit
/// `@available` on ``streamChatCompletion(request:endpoint:)`` documents
/// the floor and keeps a linter-like guard in place if the package ever
/// drops its minimums.
public actor HermesClient {
    private let session: URLSession

    /// Shared decoder for all JSON responses. Uses `convertFromSnakeCase`
    /// so wire fields like `finish_reason` / `owned_by` automatically land
    /// on Swift camelCase properties. Types that have explicit `CodingKeys`
    /// (see ``ChatCompletionChunk``) override this for specific keys.
    private let decoder: JSONDecoder

    private let encoder: JSONEncoder

    /// Maximum number of bytes we drain from an error response body before
    /// giving up. Keeps a rogue server from handing us a multi-megabyte
    /// stacktrace.
    private static let errorBodyByteLimit = 4096

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    // MARK: - Models

    /// Fetches the list of available models from the given endpoint.
    public func listModels(endpoint: HermesEndpoint) async throws -> [ModelInfo] {
        let request = try buildRequest(path: "/models", method: "GET", endpoint: endpoint)
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

    /// Starts a streaming chat completion against the given endpoint.
    ///
    /// Returns an async sequence of content deltas (already parsed strings).
    /// Cancel the surrounding Task to cancel the stream — the cancellation is
    /// surfaced to the consumer as a `CancellationError`, not as a
    /// ``HermesError/transport(_:)``.
    ///
    /// Error semantics:
    /// - HTTP non-2xx → ``HermesError/httpStatus(code:body:)`` with up to
    ///   ``errorBodyByteLimit`` bytes of body drained from the stream.
    /// - Backend sends a `{"error": {...}}` SSE frame →
    ///   ``HermesError/inStream(_:)`` with the backend's message.
    /// - JSON decode failure on a frame → ``HermesError/decoding(_:)`` — we
    ///   no longer silently drop malformed chunks.
    /// - URLError / DNS / TLS → ``HermesError/transport(_:)``.
    /// - Cancellation → `CancellationError`.
    @available(macOS 12.0, iOS 15.0, *)
    public func streamChatCompletion(
        request: ChatCompletionRequest,
        endpoint: HermesEndpoint
    ) async throws -> AsyncThrowingStream<String, Error> {
        var httpRequest = try buildRequest(path: "/chat/completions", method: "POST", endpoint: endpoint)
        httpRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        httpRequest.httpBody = try encoder.encode(request)

        // Transport call. Propagate CancellationError / URLError.cancelled as-is;
        // wrap only real transport failures as HermesError.transport.
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: httpRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch let urlError as URLError {
            throw HermesError.transport(
                "\(urlError.localizedDescription) (\(urlError.code.rawValue))"
            )
        } catch {
            throw HermesError.transport(String(describing: error))
        }

        // Early HTTP status check: if non-2xx, drain up to 4 KB of the body so
        // the caller sees *why* the backend rejected the request.
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesError.transport("No HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = await Self.drainErrorBody(bytes: bytes)
            throw HermesError.httpStatus(code: httpResponse.statusCode, body: body)
        }

        // Happy path. Hand the byte stream to the parsing pipeline inside an
        // AsyncThrowingStream so consumers can cancel it via Task.cancel().
        let localDecoder = decoder
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.pumpEvents(
                        bytes: bytes,
                        decoder: localDecoder,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch let urlError as URLError where urlError.code == .cancelled {
                    continuation.finish(throwing: CancellationError())
                } catch let hermesError as HermesError {
                    continuation.finish(throwing: hermesError)
                } catch let urlError as URLError {
                    continuation.finish(throwing: HermesError.transport(
                        "\(urlError.localizedDescription) (\(urlError.code.rawValue))"
                    ))
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

    /// Reads SSE events from `bytes` and yields their content deltas into
    /// `continuation`. Non-Hermes errors (CancellationError, URLError) are
    /// passed through so the caller can handle them; any structured backend
    /// error is mapped to ``HermesError/inStream(_:)``.
    ///
    /// Note: we deliberately feed the raw byte stream through
    /// ``SSEByteLineSequence`` instead of `bytes.lines`. The built-in
    /// `AsyncLineSequence` collapses consecutive newlines, which hides the
    /// blank-line delimiters SSE uses between events — with that the parser
    /// would run every frame together until EOF.
    private static func pumpEvents(
        bytes: URLSession.AsyncBytes,
        decoder: JSONDecoder,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let lines = SSEByteLineSequence(bytes: bytes)
        let eventStream = SSELineStream(lines: lines)
        for try await event in eventStream {
            if event.isDone {
                return
            }
            guard let payload = event.data.data(using: .utf8) else {
                // Non-UTF-8 data line — skip. This has never been observed
                // against the real backend but we don't want to crash on it.
                continue
            }

            let chunk: ChatCompletionChunk
            do {
                chunk = try decoder.decode(ChatCompletionChunk.self, from: payload)
            } catch {
                throw HermesError.decoding(String(describing: error))
            }

            // Structured in-stream error takes precedence over any content.
            if let apiError = chunk.apiError {
                throw HermesError.inStream(apiError.message)
            }

            if let content = chunk.choices.first?.delta?.content, !content.isEmpty {
                continuation.yield(content)
            }
            if chunk.choices.first?.finishReason != nil {
                return
            }
        }
    }

    /// Drains up to ``errorBodyByteLimit`` bytes from `bytes` and decodes as
    /// UTF-8 on a best-effort basis. Returns `nil` if the body is empty or
    /// unreadable. Never throws — a drain failure is itself just "no body".
    private static func drainErrorBody(bytes: URLSession.AsyncBytes) async -> String? {
        var buffer = Data()
        buffer.reserveCapacity(Self.errorBodyByteLimit)
        do {
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= Self.errorBodyByteLimit {
                    break
                }
            }
        } catch {
            // If the drain itself fails, we still want to surface what we got.
        }
        guard !buffer.isEmpty else { return nil }
        return String(data: buffer, encoding: .utf8)
    }

    /// Builds a `URLRequest` targeting the given endpoint.
    private func buildRequest(
        path: String,
        method: String,
        endpoint: HermesEndpoint
    ) throws -> URLRequest {
        let fullURL = endpoint.baseURL.appending(path: path)
        var request = URLRequest(url: fullURL)
        request.httpMethod = method
        request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        return request
    }

    /// Validates a non-streaming response. The streaming path has its own
    /// body-draining logic and does not go through here.
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
