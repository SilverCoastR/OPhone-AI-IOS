import XCTest
@testable import OPhoneAI

final class TaskControllerTests: XCTestCase {
    func testSameHumanTurnReturnsSameDurableTask() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = FileStore(root: root), events = EventBus(files: files), controller = TaskController(files: files, events: events)
        let one = try await controller.begin(conversationID: "c:test", humanKey: "m1", goal: "write a note")
        let two = try await controller.begin(conversationID: "c:test", humanKey: "m1", goal: "write a note")
        XCTAssertEqual(one.id, two.id)
        XCTAssertEqual((await events.query(taskID: one.id)).filter { $0.type == "task_created" }.count, 1)
    }

    func testCompletionRequiresEvidence() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = FileStore(root: root), controller = TaskController(files: files, events: EventBus(files: files))
        let task = try await controller.begin(conversationID: "c:test", humanKey: "m2", goal: "answer")
        do { _ = try await controller.finish(taskID: task.id, summary: "done", evidence: [:]); XCTFail("Expected evidence error") }
        catch { XCTAssertTrue(error is TaskError) }
    }
}
