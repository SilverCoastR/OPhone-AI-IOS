import Foundation

actor ConversationStore {
    private struct State: Codable { var activeID: String?; var conversations: [Conversation] }
    private let files: FileStore
    private let filename = "conversations.json"
    private let maxContextMessages = 80
    private let maxContextBytes = 384 * 1_024

    init(files: FileStore) { self.files = files }

    private func load() async throws -> State { try await files.load(State.self, from: filename, fallback: State(activeID: nil, conversations: [])) }
    private func save(_ state: State) async throws { try await files.save(state, to: filename) }

    func bootstrap(provider: String) async throws -> Conversation {
        var state = try await load()
        if let id = state.activeID, let current = state.conversations.first(where: { $0.id == id }) { return current }
        let conversation = makeConversation(provider: provider)
        state.conversations.append(conversation); state.activeID = conversation.id
        try await save(state); return conversation
    }

    func list() async throws -> [Conversation] { try await load().conversations.sorted { $0.updatedAt > $1.updatedAt } }
    func active() async throws -> Conversation? { let state = try await load(); return state.conversations.first { $0.id == state.activeID } }

    @discardableResult func create(provider: String) async throws -> Conversation {
        var state = try await load()
        if let empty = state.conversations.first(where: { $0.messages.isEmpty }) {
            state.activeID = empty.id; try await save(state); return empty
        }
        let conversation = makeConversation(provider: provider)
        state.conversations.append(conversation); state.activeID = conversation.id
        if state.conversations.count > 500 { state.conversations.sort { $0.updatedAt > $1.updatedAt }; state.conversations = Array(state.conversations.prefix(500)) }
        try await save(state); return conversation
    }

    func select(_ id: String) async throws {
        var state = try await load()
        guard state.conversations.contains(where: { $0.id == id }) else { throw StoreError.notFound }
        state.activeID = id; try await save(state)
    }

    @discardableResult func delete(_ id: String, provider: String) async throws -> Conversation {
        var state = try await load(); state.conversations.removeAll { $0.id == id }
        if state.conversations.isEmpty { state.conversations = [makeConversation(provider: provider)] }
        if state.activeID == id || !state.conversations.contains(where: { $0.id == state.activeID }) { state.activeID = state.conversations.max(by: { $0.updatedAt < $1.updatedAt })!.id }
        try await save(state); return state.conversations.first { $0.id == state.activeID }!
    }

    func append(_ message: ChatMessage, to id: String) async throws {
        var state = try await load(); guard let index = state.conversations.firstIndex(where: { $0.id == id }) else { throw StoreError.notFound }
        state.conversations[index].messages.append(message); state.conversations[index].updatedAt = Date()
        if let provider = message.provider, !provider.isEmpty { state.conversations[index].lastProvider = provider }
        if message.role == .user, state.conversations[index].title == "New conversation" {
            let cleaned = message.content.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            state.conversations[index].title = String(cleaned.prefix(42))
        }
        try await save(state)
    }

    func replace(_ message: ChatMessage, in id: String) async throws {
        var state = try await load(); guard let index = state.conversations.firstIndex(where: { $0.id == id }), let messageIndex = state.conversations[index].messages.firstIndex(where: { $0.id == message.id }) else { throw StoreError.notFound }
        state.conversations[index].messages[messageIndex] = message; state.conversations[index].updatedAt = Date(); try await save(state)
    }

    func deleteMessage(_ messageID: UUID, in id: String) async throws {
        var state = try await load(); guard let index = state.conversations.firstIndex(where: { $0.id == id }), let at = state.conversations[index].messages.firstIndex(where: { $0.id == messageID }) else { throw StoreError.notFound }
        if state.conversations[index].messages[at].role == .user {
            let next = state.conversations[index].messages[(at + 1)...].firstIndex(where: { $0.role == .user }) ?? state.conversations[index].messages.endIndex
            state.conversations[index].messages.removeSubrange(at..<next)
        } else { state.conversations[index].messages.remove(at: at) }
        state.conversations[index].updatedAt = Date(); try await save(state)
    }

    func allowProvider(_ provider: String, conversation id: String) async throws {
        var state = try await load(); guard let index = state.conversations.firstIndex(where: { $0.id == id }) else { throw StoreError.notFound }
        state.conversations[index].allowedProviders.insert(provider); try await save(state)
    }

    func context(for id: String) async throws -> [ChatMessage] {
        let state = try await load(); guard let conversation = state.conversations.first(where: { $0.id == id }) else { throw StoreError.notFound }
        var messages = conversation.messages.filter { $0.role != .progress && !$0.isInternal }
        while messages.count > maxContextMessages || ((try? JSONEncoder().encode(messages).count) ?? 0) > maxContextBytes {
            if let index = messages.dropLast().firstIndex(where: { $0.role == .tool && $0.content.count > 512 }) {
                messages[index].content = "{\"ok\":true,\"summary\":\"Older tool output was compacted. Inspect current state if needed.\"}"
            } else if messages.count > 1 {
                let nextHuman = messages.dropFirst().firstIndex(where: { $0.role == .user }) ?? messages.index(after: messages.startIndex)
                messages.removeSubrange(messages.startIndex..<nextHuman)
            } else { break }
        }
        return messages
    }

    func removeAll() async throws { try await files.remove(filename) }

    private func makeConversation(provider: String) -> Conversation {
        let now = Date(); return Conversation(id: "c:api.\(provider).\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))", title: "New conversation", createdAt: now, updatedAt: now, lastProvider: provider)
    }
}

enum StoreError: LocalizedError { case notFound, invalidValue; var errorDescription: String? { switch self { case .notFound: return "The local record was not found."; case .invalidValue: return "The local record is invalid." } } }
