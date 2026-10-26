import XCTest
@testable import OPhoneAI

final class ModelRequestBuilderTests: XCTestCase {
    func testAnthropicToolResultsBecomeUserBlocks() {
        let call = ToolCall(id: "call-1", name: "workspace_read", arguments: ["path": .string("a.txt")])
        let messages = [ChatMessage(role: .user, content: "read"), ChatMessage(role: .assistant, content: "", toolCalls: [call]), ChatMessage(role: .tool, content: "ok", toolCallID: "call-1")]
        let output = ModelRequestBuilder.anthropicMessages(messages)
        XCTAssertEqual(output.messages.count, 3)
        XCTAssertEqual(output.messages[1]["role"] as? String, "assistant")
        XCTAssertEqual(output.messages[2]["role"] as? String, "user")
    }
}
