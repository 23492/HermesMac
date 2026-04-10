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
