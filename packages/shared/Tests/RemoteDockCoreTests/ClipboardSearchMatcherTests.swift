import XCTest
@testable import RemoteDockCore

final class ClipboardSearchMatcherTests: XCTestCase {
    func testMatchesChineseByOriginalText() {
        XCTAssertTrue(ClipboardSearchMatcher.matches("苹果生态剪贴板", query: "剪贴"))
    }

    func testMatchesChineseByFullPinyin() {
        XCTAssertTrue(ClipboardSearchMatcher.matches("苹果生态剪贴板", query: "jian tie"))
        XCTAssertTrue(ClipboardSearchMatcher.matches("苹果生态剪贴板", query: "jiantie"))
    }

    func testMatchesChineseByPinyinInitials() {
        XCTAssertTrue(ClipboardSearchMatcher.matches("苹果生态剪贴板", query: "pgstjtb"))
        XCTAssertTrue(ClipboardSearchMatcher.matches("苹果生态剪贴板", query: "jtb"))
    }

    func testMatchesClipboardItemSourceBundleId() {
        let item = ClipboardItem(
            id: "id",
            plainText: "普通文本",
            sourceAppBundleId: "com.example.notes",
            createdAt: Date(timeIntervalSince1970: 1),
            contentHash: "hash"
        )

        XCTAssertTrue(ClipboardSearchMatcher.matches(item, query: "example"))
    }

    func testMatchesImageClipboardItemDisplayText() {
        let item = ClipboardItem(
            id: "id",
            contentType: .image,
            plainText: "Image file 120x80",
            richRepresentations: [
                ClipboardRepresentation(kind: .png, data: Data([1]))
            ],
            imageMetadata: ClipboardImageMetadata(
                formatIdentifier: "public.png",
                pixelWidth: 120,
                pixelHeight: 80,
                bytesLength: 1
            ),
            sourceAppBundleId: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            contentHash: "hash"
        )

        XCTAssertTrue(ClipboardSearchMatcher.matches(item, query: "120x80"))
        XCTAssertTrue(ClipboardSearchMatcher.matches(item, query: "image"))
    }

    func testDoesNotMatchUnrelatedQuery() {
        XCTAssertFalse(ClipboardSearchMatcher.matches("苹果生态剪贴板", query: "banana"))
    }
}
