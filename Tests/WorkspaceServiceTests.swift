import XCTest
@testable import OPhoneAI

final class WorkspaceServiceTests: XCTestCase {
    func testReadWriteAndTraversalProtection() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = WorkspaceService(root: root)
        _ = try await workspace.write(path: "notes/test.txt", text: "hello")
        let contents = try await workspace.read(path: "notes/test.txt")
        XCTAssertEqual(contents, "hello")
        do { _ = try await workspace.read(path: "../outside"); XCTFail("Expected path rejection") }
        catch { XCTAssertTrue(error is WorkspaceService.WorkspaceError) }
    }
}
