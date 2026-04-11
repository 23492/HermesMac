import Foundation

// MARK: - Request

/// A `POST /v1/chat/completions` request body for the Hermes backend.
///
/// The backend consumes OpenAI chat-completions-shaped JSON. We only
/// surface the subset of fields we actually use.
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

    /// Explicit coding keys so the request body matches the OpenAI wire
    /// format exactly, regardless of what `JSONEncoder.keyEncodingStrategy`
    /// does elsewhere.
    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

/// A single message in a chat-completions exchange.
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
///
/// We decode only the subset of fields we actually care about. The decoder
/// used to parse these is configured with
/// ``Foundation/JSONDecoder/KeyDecodingStrategy/convertFromSnakeCase`` — see
/// ``HermesClient`` — so fields like `finish_reason` land on
/// ``Choice/finishReason`` automatically. Nested `CodingKeys` that remap
/// into snake_case shapes are therefore unnecessary here.
///
/// If the backend fails mid-stream it may send a frame that contains an
/// ``apiError`` object instead of (or alongside) `choices`. The networking
/// layer promotes that into ``HermesError/inStream(_:)``.
public struct ChatCompletionChunk: Decodable, Sendable {
    public let id: String?
    public let model: String?
    public let choices: [Choice]
    public let apiError: APIError?

    public init(
        id: String? = nil,
        model: String? = nil,
        choices: [Choice] = [],
        apiError: APIError? = nil
    ) {
        self.id = id
        self.model = model
        self.choices = choices
        self.apiError = apiError
    }

    /// Decodes the chunk. We hand-roll `init(from:)` because:
    ///  - `choices` is missing on pure-error frames, so we default to `[]`
    ///    instead of failing the whole decode.
    ///  - The `error` key on the wire must map to ``apiError``, and the
    ///    `convertFromSnakeCase` strategy does not help here since `error`
    ///    is already a single lowercased word.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.choices = try container.decodeIfPresent([Choice].self, forKey: .choices) ?? []
        self.apiError = try container.decodeIfPresent(APIError.self, forKey: .apiError)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case model
        case choices
        case apiError = "error"
    }

    public struct Choice: Decodable, Sendable {
        public let delta: Delta?
        public let finishReason: String?

        // finishReason is picked up automatically by convertFromSnakeCase.
    }

    public struct Delta: Decodable, Sendable {
        public let role: String?
        public let content: String?
    }

    /// Structured error payload the backend can send inside an SSE frame
    /// when something blows up mid-stream. Mirrors the shape used by
    /// `GET /v1/models` and friends.
    public struct APIError: Decodable, Sendable, Equatable {
        public let message: String
        public let type: String?
        public let code: String?

        public init(message: String, type: String? = nil, code: String? = nil) {
            self.message = message
            self.type = type
            self.code = code
        }
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

    // ownedBy is picked up automatically by convertFromSnakeCase.
}
