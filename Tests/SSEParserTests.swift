import XCTest
@testable import OPhoneAI

final class SSEParserTests: XCTestCase {
    func testCombinesMultilineDataAndResetsEvent() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(line: "event: message"))
        XCTAssertNil(parser.consume(line: "data: one"))
        XCTAssertNil(parser.consume(line: "data: two"))
        let event = parser.consume(line: "")
        XCTAssertEqual(event?.event, "message")
        XCTAssertEqual(event?.data, "one\ntwo")
        XCTAssertNil(parser.consume(line: ""))
    }

    func testIgnoresComments() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(line: ": keepalive"))
        XCTAssertNil(parser.finish())
    }
}
