import Foundation

enum MessageRole: String, Codable, Sendable { case system, user, assistant, tool, progress }

struct ToolCall: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var arguments: JSONObject
}

struct ChatAttachment: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var mimeType: String
    var localPath: String
}

struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var role: MessageRole
    var content: String
    var reasoning: String? = nil
    var toolCalls: [ToolCall] = []
    var toolCallID: String? = nil
    var provider: String? = nil
    var createdAt = Date()
    var isInternal = false
    var attachments: [ChatAttachment] = []
}

struct Conversation: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var lastProvider: String
    var allowedProviders: Set<String> = []
    var messages: [ChatMessage] = []
}

enum AgentTaskStatus: String, Codable, CaseIterable, Sendable {
    case running, waitingEvent, waitingUser, succeeded, blocked, failed, cancelled
    var isTerminal: Bool { [.succeeded, .blocked, .failed, .cancelled].contains(self) }
}

struct CompletionCriterion: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var kind: String
    var expected: JSONObject
}

struct TaskCheckpoint: Codable, Equatable, Sendable {
    var summary: String
    var nextAction: String
    var completedSteps: [String]
    var remainingSteps: [String]
    var blockers: [String]
    var updatedAt = Date()
}

struct AgentTaskRecord: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var conversationID: String
    var humanKey: String
    var goal: String
    var status: AgentTaskStatus
    var createdAt: Date
    var updatedAt: Date
    var deadline: Date
    var criteria: [CompletionCriterion] = []
    var checkpoint: TaskCheckpoint? = nil
    var summary: String? = nil
    var endReason: String? = nil
    var toolCount = 0
    var actionCount = 0
}

struct AgentEvent: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var taskID: String
    var type: String
    var source: String
    var level: String
    var data: JSONObject
    var createdAt = Date()
    var acknowledgedAt: Date? = nil
}

struct AuditEntry: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var taskID: String?
    var tool: String
    var success: Bool
    var detail: String
    var createdAt = Date()
}

struct MemoryEntry: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var category: String
    var text: String
    var tags: [String]
    var createdAt = Date()
    var updatedAt = Date()
}

enum ControlPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case chatGPTWeb = "chatgpt_web"
    case deepSeek = "deepseek"
    case openAI = "openai"
    case claude = "claude"
    var id: String { rawValue }
    var title: String {
        switch self { case .chatGPTWeb: return "ChatGPT Web"; case .deepSeek: return "DeepSeek"; case .openAI: return "OpenAI"; case .claude: return "Claude" }
    }
    var isAPI: Bool { self != .chatGPTWeb }
}

enum ProviderProtocolKind: String, Codable, Sendable { case openAIChat = "openai_chat", anthropicMessages = "anthropic_messages" }

struct ProviderDescriptor: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var company: String
    var protocolKind: ProviderProtocolKind
    var baseURL: String
    var models: [String]
    var editableBaseURL: Bool
    var supportsThinking: Bool

    static let bundled: [ProviderDescriptor] = [
        .init(id: "deepseek", name: "DeepSeek", company: "DeepSeek", protocolKind: .openAIChat, baseURL: "https://api.deepseek.com", models: ["deepseek-chat", "deepseek-reasoner"], editableBaseURL: false, supportsThinking: true),
        .init(id: "openai", name: "OpenAI", company: "OpenAI", protocolKind: .openAIChat, baseURL: "https://api.openai.com/v1", models: [], editableBaseURL: true, supportsThinking: true),
        .init(id: "claude", name: "Claude", company: "Anthropic", protocolKind: .anthropicMessages, baseURL: "https://api.anthropic.com/v1", models: [], editableBaseURL: false, supportsThinking: false)
    ]
}

struct ProviderConfiguration: Codable, Equatable, Sendable {
    var providerID: String
    var model: String
    var baseURL: String
    var maxTokens: Int = 8_192
    var thinking = false
    var reasoningEffort = "high"
    var temperature: Double? = nil
    var topP: Double? = nil
    var customInstructions = ""
}
