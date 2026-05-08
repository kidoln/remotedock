import XCTest
@testable import RemoteDockCore

final class CommandInboxTests: XCTestCase {
    func testCachesCommandResult() async {
        let inbox = CommandInbox<String>()

        await inbox.store("ok", for: "command-1")

        let result = await inbox.cachedResult(for: "command-1")
        XCTAssertEqual(result, "ok")
    }

    func testEvictsOldestResultWhenCapacityIsExceeded() async {
        let inbox = CommandInbox<String>(capacity: 1)

        await inbox.store("first", for: "command-1")
        await inbox.store("second", for: "command-2")

        let first = await inbox.cachedResult(for: "command-1")
        let second = await inbox.cachedResult(for: "command-2")

        XCTAssertNil(first)
        XCTAssertEqual(second, "second")
    }
}
