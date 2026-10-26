import XCTest
@testable import OPhoneAI

final class ConversationStoreTests: XCTestCase {
    func testPersistsConversationAndBoundsOnlyModelContext() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ConversationStore(files: FileStore(root: root))
        let conversation = try await store.bootstrap(provider: "deepseek")
        for index in 0..<100 { try await store.append(ChatMessage(role: index.isMultiple(of: 2) ? .user : .assistant, content: "message \(index)"), to: conversation.id) }
        let visible = try await store.active()
        XCTAssertEqual(visible?.messages.count, 100)
        let context = try await store.context(for: conversation.id)
        XCTAssertLessThanOrEqual(context.count, 80)
        XCTAssertEqual(context.last?.content, "message 99")
    }

    func testDeleteHumanMessageRemovesItsReplyTurn() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ConversationStore(files: FileStore(root: root)); let conversation = try await store.bootstrap(provider: "openai")
        let first = ChatMessage(role: .user, content: "first"), answer = ChatMessage(role: .assistant, content: "answer"), next = ChatMessage(role: .user, content: "next")
        try await store.append(first, to: conversation.id); try await store.append(answer, to: conversation.id); try await store.append(next, to: conversation.id)
        try await store.deleteMessage(first.id, in: conversation.id)
        let remainingContents = try await store.active()?.messages.map(\.content)
        XCTAssertEqual(remainingContents, ["next"])
    }
}
