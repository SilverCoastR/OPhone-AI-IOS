import CryptoKit
import Foundation

actor TaskController {
    private struct State: Codable { var tasks: [AgentTaskRecord] = [] }
    private let files: FileStore
    private let events: EventBus
    private let name = "tasks.json"
    init(files: FileStore, events: EventBus) { self.files = files; self.events = events }

    private func load() async throws -> State { try await files.load(State.self, from: name, fallback: State()) }
    private func save(_ state: State) async throws { try await files.save(state, to: name) }

    func begin(conversationID: String, humanKey: String, goal: String, budgetMinutes: Int = 45) async throws -> AgentTaskRecord {
        let clean = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard conversationID.hasPrefix("c:"), !humanKey.isEmpty, !clean.isEmpty, clean.count <= 8_192 else { throw StoreError.invalidValue }
        var state = try await load()
        if let existing = state.tasks.first(where: { $0.conversationID == conversationID && $0.humanKey == humanKey }) { return existing }
        for index in state.tasks.indices where state.tasks[index].conversationID == conversationID && !state.tasks[index].status.isTerminal {
            state.tasks[index].status = .cancelled; state.tasks[index].endReason = "superseded_by_new_user_request"; state.tasks[index].updatedAt = Date()
        }
        let digest = SHA256.hash(data: Data("\(conversationID)\n\(humanKey)".utf8)).map { String(format: "%02x", $0) }.joined()
        let now = Date()
        let task = AgentTaskRecord(id: "task-\(digest.prefix(32))", conversationID: conversationID, humanKey: humanKey, goal: clean, status: .running, createdAt: now, updatedAt: now, deadline: now.addingTimeInterval(TimeInterval(max(5, min(240, budgetMinutes)) * 60)))
        state.tasks.append(task); try await save(state)
        await events.publish(taskID: task.id, type: "task_created", source: "task", data: ["goal": .string(clean)])
        return task
    }

    func task(_ id: String) async throws -> AgentTaskRecord {
        guard let task = try await load().tasks.first(where: { $0.id == id }) else { throw StoreError.notFound }; return task
    }
    func list(conversationID: String? = nil) async throws -> [AgentTaskRecord] {
        try await load().tasks.filter { conversationID == nil || $0.conversationID == conversationID }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func checkpoint(taskID: String, checkpoint: TaskCheckpoint) async throws -> AgentTaskRecord {
        var state = try await load(); let index = try index(taskID, in: state)
        guard !state.tasks[index].status.isTerminal else { throw TaskError.alreadyTerminal }
        guard !checkpoint.summary.isEmpty, !checkpoint.nextAction.isEmpty else { throw StoreError.invalidValue }
        state.tasks[index].checkpoint = checkpoint; state.tasks[index].updatedAt = Date(); state.tasks[index].status = .running
        try await save(state); await events.publish(taskID: taskID, type: "checkpoint_saved", source: "task", data: ["summary": .string(checkpoint.summary)])
        return state.tasks[index]
    }

    func incrementTool(taskID: String, mutating: Bool) async {
        guard var state = try? await load(), let index = state.tasks.firstIndex(where: { $0.id == taskID }), !state.tasks[index].status.isTerminal else { return }
        state.tasks[index].toolCount += 1; if mutating { state.tasks[index].actionCount += 1 }; state.tasks[index].updatedAt = Date(); try? await save(state)
    }

    func setCriteria(taskID: String, criteria: [CompletionCriterion]) async throws -> AgentTaskRecord {
        guard criteria.count <= 20 else { throw StoreError.invalidValue }
        var state = try await load(); let index = try index(taskID, in: state); guard !state.tasks[index].status.isTerminal else { throw TaskError.alreadyTerminal }
        state.tasks[index].criteria = criteria; state.tasks[index].updatedAt = Date(); try await save(state); return state.tasks[index]
    }

    func waitForUser(taskID: String, reason: String) async throws -> AgentTaskRecord { try await transition(taskID, to: .waitingUser, summary: nil, reason: reason) }
    func waitForEvent(taskID: String, reason: String) async throws -> AgentTaskRecord { try await transition(taskID, to: .waitingEvent, summary: nil, reason: reason) }

    func finish(taskID: String, summary: String, evidence: JSONObject) async throws -> AgentTaskRecord {
        guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !evidence.isEmpty else { throw TaskError.evidenceRequired }
        return try await transition(taskID, to: .succeeded, summary: summary, reason: "verified_by_app_scoped_evidence")
    }

    func fail(taskID: String, reason: String) async throws -> AgentTaskRecord { try await transition(taskID, to: .failed, summary: nil, reason: reason) }
    func cancel(taskID: String, reason: String = "cancelled_by_user") async throws -> AgentTaskRecord { try await transition(taskID, to: .cancelled, summary: nil, reason: reason) }

    private func transition(_ taskID: String, to status: AgentTaskStatus, summary: String?, reason: String) async throws -> AgentTaskRecord {
        var state = try await load(); let index = try index(taskID, in: state)
        if state.tasks[index].status.isTerminal { return state.tasks[index] }
        state.tasks[index].status = status; state.tasks[index].summary = summary; state.tasks[index].endReason = reason; state.tasks[index].updatedAt = Date()
        try await save(state); await events.publish(taskID: taskID, type: "task_\(status.rawValue)", source: "task", level: status == .failed ? "error" : "info", data: ["reason": .string(reason), "summary": summary.map(JSONValue.string) ?? .null])
        return state.tasks[index]
    }

    private func index(_ id: String, in state: State) throws -> Int { guard let index = state.tasks.firstIndex(where: { $0.id == id }) else { throw StoreError.notFound }; return index }
}

enum TaskError: LocalizedError {
    case alreadyTerminal, evidenceRequired
    var errorDescription: String? { switch self { case .alreadyTerminal: return "The task is already finished."; case .evidenceRequired: return "A completion summary and app-scoped evidence are required." } }
}
