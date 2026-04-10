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
                        guard let chunk = try? localDecoder.decode(
                            ChatCompletionChunk.self, from: payload
                        ) else {
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
