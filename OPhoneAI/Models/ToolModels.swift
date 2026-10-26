import Foundation

struct ToolDefinition: Identifiable, Codable, Equatable, Sendable {
    var id: String { name }
    var name: String
    var summary: String
    var parameters: JSONObject

    var openAIDictionary: [String: Any] {
        ["type": "function", "function": ["name": name, "description": summary, "parameters": JSONValue.object(parameters).any]]
    }
}

struct ToolContext: Sendable {
    var taskID: String
    var conversationID: String
    var callID: String
}

enum ModelStreamEvent: Sendable {
    case text(String)
    case thinking
    case status(String)
}

struct ModelResponse: Sendable {
    var content: String
    var reasoning: String
    var toolCalls: [ToolCall]
    var finishReason: String
    var usage: JSONObject
}

enum ModelTransportError: LocalizedError {
    case invalidURL, invalidResponse, http(Int, String), missingModel, cancelled
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The model endpoint URL is invalid."
        case .invalidResponse: return "The model service returned an invalid response."
        case .missingModel: return "Choose a model before sending a message."
        case let .http(status, body): return "Model API HTTP \(status): \(body)"
        case .cancelled: return "The model request was cancelled."
        }
    }
}

protocol ModelTransport: Sendable {
    func listModels(apiKey: String, config: ProviderConfiguration) async throws -> [String]
    func stream(apiKey: String, config: ProviderConfiguration, messages: [ChatMessage], tools: [ToolDefinition], onEvent: @escaping @Sendable (ModelStreamEvent) -> Void) async throws -> ModelResponse
}
