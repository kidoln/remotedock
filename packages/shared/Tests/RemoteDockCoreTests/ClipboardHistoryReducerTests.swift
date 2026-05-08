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

    func testMakeItemPreservesRichRepresentations() throws {
        let representation = ClipboardRepresentation(
            kind: .rtf,
            data: Data("{\\rtf1\\b Hello}".utf8)
        )

        let item = try XCTUnwrap(ClipboardHistoryReducer.makeItem(
            text: "Hello",
            richRepresentations: [representation],
            sourceAppBundleId: nil,
            now: Date(timeIntervalSince1970: 1)
        ))

        XCTAssertEqual(item.richRepresentations, [representation])
        XCTAssertNotEqual(item.contentHash, ClipboardHistoryReducer.contentHash(for: "Hello"))
    }

    func testNormalizedRepresentationsDeduplicatesAndSkipsOversizedData() {
        let representations = [
            ClipboardRepresentation(kind: .rtf, data: Data([1, 2, 3])),
            ClipboardRepresentation(kind: .rtf, data: Data([4, 5, 6])),
            ClipboardRepresentation(kind: .html, data: Data([7, 8, 9]))
        ]

        let normalized = ClipboardHistoryReducer.normalizedRepresentations(
            representations,
            maxBytes: 5
        )

        XCTAssertEqual(normalized, [
            ClipboardRepresentation(kind: .rtf, data: Data([1, 2, 3]))
        ])
    }

    func testNormalizedRepresentationsKeepsLaterSmallItemWhenFirstItemIsOversized() {
        let representations = [
            ClipboardRepresentation(kind: .rtf, data: Data([1, 2, 3, 4, 5, 6])),
            ClipboardRepresentation(kind: .rtf, data: Data([7, 8, 9]))
        ]

        let normalized = ClipboardHistoryReducer.normalizedRepresentations(
            representations,
            maxBytes: 5
        )

        XCTAssertEqual(normalized, [
            ClipboardRepresentation(kind: .rtf, data: Data([7, 8, 9]))
        ])
    }

    func testClipboardRepresentationKindPreservesCustomPasteboardTypes() throws {
        let kind = ClipboardRepresentationKind(pasteboardTypeIdentifier: "com.microsoft.word.custom-format")
        XCTAssertEqual(kind.rawValue, "com.microsoft.word.custom-format")
        XCTAssertEqual(kind.pasteboardTypeIdentifier, "com.microsoft.word.custom-format")

        let data = try JSONEncoder().encode(kind)
        let decodedKind = try JSONDecoder().decode(ClipboardRepresentationKind.self, from: data)

        XCTAssertEqual(decodedKind, kind)
    }

    func testDecodesLegacyClipboardItemWithoutRichRepresentations() throws {
        let json = """
        {
          "id": "id",
          "contentType": "text",
          "plainText": "legacy",
          "sourceAppBundleId": null,
          "createdAt": "1970-01-01T00:00:01Z",
          "contentHash": "hash"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = try decoder.decode(ClipboardItem.self, from: Data(json.utf8))

        XCTAssertEqual(item.plainText, "legacy")
        XCTAssertEqual(item.richRepresentations, [])
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
