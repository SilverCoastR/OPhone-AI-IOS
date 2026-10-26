import Foundation

enum AgentRunUpdate: Sendable {
    case status(String)
    case text(String)
    case thinking
    case tool(name: String)
    case finished(AgentTaskStatus)
}

final class DirectModelAgent: @unchecked Sendable {
    private let conversations: ConversationStore
    private let tasks: TaskController
    private let kernel: ToolKernel
    private let settings: ProviderSettingsStore

    init(conversations: ConversationStore, tasks: TaskController, kernel: ToolKernel, settings: ProviderSettingsStore) {
        self.conversations = conversations; self.tasks = tasks; self.kernel = kernel; self.settings = settings
    }

    func run(conversationID: String, userMessage: ChatMessage, provider: ProviderDescriptor, maxSteps: Int = 24, onUpdate: @escaping @Sendable (AgentRunUpdate) -> Void) async throws {
        let task = try await tasks.begin(conversationID: conversationID, humanKey: userMessage.id.uuidString, goal: userMessage.content)
        let config = try await settings.configuration(for: provider), apiKey = try await settings.apiKey(for: provider.id)
        let transport: any ModelTransport = provider.protocolKind == .anthropicMessages ? AnthropicTransport() : OpenAICompatibleTransport()
        let tools = await kernel.definitions()
        onUpdate(.status("Planning"))
        do {
            for step in 0..<max(1, min(64, maxSteps)) {
                try Task.checkCancellation()
                let current = try await tasks.task(task.id); if current.status.isTerminal { onUpdate(.finished(current.status)); return }
                var context = try await conversations.context(for: conversationID)
                context.insert(ChatMessage(role: .system, content: AgentPrompt.system(customInstructions: config.customInstructions), provider: provider.id, isInternal: true), at: 0)
                let response = try await transport.stream(apiKey: apiKey, config: config, messages: context, tools: tools) { event in
                    switch event {
                    case let .text(part): onUpdate(.text(part))
                    case .thinking: onUpdate(.thinking)
                    case let .status(value): onUpdate(.status(value))
                    }
                }
                let assistant = ChatMessage(role: .assistant, content: response.content, reasoning: response.reasoning.isEmpty ? nil : response.reasoning, toolCalls: response.toolCalls, provider: provider.id)
                try await conversations.append(assistant, to: conversationID)
                if response.toolCalls.isEmpty {
                    if actionLike(userMessage.content) {
                        _ = try await tasks.waitForUser(taskID: task.id, reason: response.content.isEmpty ? "The model stopped without completing the requested action." : "The model returned without app-scoped completion evidence.")
                        onUpdate(.finished(.waitingUser))
                    } else {
                        _ = try await tasks.finish(taskID: task.id, summary: "Answered the user's question.", evidence: ["assistant_response": .bool(!response.content.isEmpty), "step": .number(Double(step + 1))])
                        onUpdate(.finished(.succeeded))
                    }
                    return
                }
                for call in response.toolCalls {
                    try Task.checkCancellation(); onUpdate(.tool(name: call.name))
                    let toolContext = ToolContext(taskID: task.id, conversationID: conversationID, callID: call.id)
                    let result = await kernel.execute(name: call.name, arguments: call.arguments, context: toolContext)
                    let toolMessage = ChatMessage(role: .tool, content: ModelRequestBuilder.jsonString(result), toolCallID: call.id, provider: provider.id, isInternal: true)
                    try await conversations.append(toolMessage, to: conversationID)
                    let updated = try await tasks.task(task.id); if updated.status.isTerminal { onUpdate(.finished(updated.status)); return }
                }
                if step > 0 && step % 6 == 0 { onUpdate(.status("Continuing from verified tool results")) }
            }
            _ = try await tasks.waitForUser(taskID: task.id, reason: "The configured step limit was reached. Ask the user whether to continue.")
            onUpdate(.finished(.waitingUser))
        } catch is CancellationError {
            _ = try? await tasks.cancel(taskID: task.id); onUpdate(.finished(.cancelled)); throw CancellationError()
        } catch {
            _ = try? await tasks.fail(taskID: task.id, reason: error.localizedDescription); onUpdate(.finished(.failed)); throw error
        }
    }

    private func actionLike(_ text: String) -> Bool {
        let lower = text.lowercased()
        let markers = ["打开", "创建", "保存", "写", "下载", "上传", "请求", "运行", "删除", "修改", "帮我", "open ", "create ", "save ", "write ", "download", "upload", "run ", "delete ", "change ", "please "]
        return markers.contains { lower.contains($0) }
    }
}
