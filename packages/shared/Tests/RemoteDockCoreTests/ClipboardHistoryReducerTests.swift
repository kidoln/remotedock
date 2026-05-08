import XCTest
@testable import RemoteDockCore

final class ClipboardHistoryReducerTests: XCTestCase {
    func testMakeItemTrimsAndHashesText() {
        let item = ClipboardHistoryReducer.makeItem(
            text: "  Hello Remote Dock  ",
            sourceAppBundleId: nil,
            now: Date(timeIntervalSince1970: 1)
        )

        XCTAssertEqual(item?.plainText, "Hello Remote Dock")
        XCTAssertEqual(item?.id, item?.contentHash)
        XCTAssertEqual(item?.contentType, .text)
    }

    func testInsertingDeduplicatesByContentHash() throws {
        let first = try XCTUnwrap(ClipboardHistoryReducer.makeItem(
            text: "same",
            sourceAppBundleId: nil,
            now: Date(timeIntervalSince1970: 1)
        ))
        let second = try XCTUnwrap(ClipboardHistoryReducer.makeItem(
            text: "same",
            sourceAppBundleId: nil,
            now: Date(timeIntervalSince1970: 2)
        ))

        let history = ClipboardHistoryReducer.inserting(second, into: [first])

        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.createdAt, Date(timeIntervalSince1970: 2))
    }

    func testMakeItemSkipsExcludedSourceApp() {
        let policy = ClipboardHistoryPolicy(excludedSourceBundleIdentifiers: ["com.example.secret"])
        let item = ClipboardHistoryReducer.makeItem(
            text: "secret",
            sourceAppBundleId: "com.example.secret",
            policy: policy
        )

        XCTAssertNil(item)
    }

    func testNormalizeTextRespectsUTF8Boundary() {
        let normalized = ClipboardHistoryReducer.normalizeText("你好abc", maxBytes: 7)

        XCTAssertEqual(normalized, "你好a")
    }
}
