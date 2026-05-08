import XCTest
import RemoteDockCore
import RemoteDockProtocol
@testable import RemoteDockTransport

final class RemoteDockMessageCodecTests: XCTestCase {
    func testEncodesAndDecodesMessageEnvelope() throws {
        let payload = PairRequestPayload(
            deviceId: "ios-1",
            deviceName: "iPhone",
            requestedAt: Date(timeIntervalSince1970: 12)
        )
        let message = RemoteDockMessage.pairRequest(payload)

        let data = try message.encodedData()
        let decoded = try RemoteDockMessage.decode(from: data)

        XCTAssertEqual(decoded, message)
    }

    func testEncodesAndDecodesIconPayload() throws {
        let payload = IconPayload(
            asset: AppIconAsset(
                hash: "com.apple.Safari",
                pixelWidth: 128,
                pixelHeight: 128,
                bytesLength: 4096
            ),
            base64PNGData: String(repeating: "a", count: 12_000)
        )
        let message = RemoteDockMessage.iconPayload(payload)

        let data = try message.encodedData()
        let decoded = try RemoteDockMessage.decode(from: data)

        XCTAssertEqual(decoded, message)
    }

    func testEncodesAndDecodesRichClipboardPasteCommand() throws {
        let payload = PasteClipboardItemCommandPayload(
            commandId: "paste-1",
            issuedAt: Date(timeIntervalSince1970: 12),
            clipboardItemId: "clipboard-1",
            plainText: "Hello",
            richRepresentations: [
                ClipboardRepresentation(kind: .rtf, data: Data("{\\rtf1 Hello}".utf8))
            ]
        )
        let message = RemoteDockMessage.pasteClipboardItemCommand(payload)

        let data = try message.encodedData()
        let decoded = try RemoteDockMessage.decode(from: data)

        XCTAssertEqual(decoded, message)
    }

    func testDecodesHelloWithUnsupportedEnvelopeVersionForNegotiation() throws {
        let json = """
        {
          "type": "hello",
          "version": 999,
          "payload": {
            "deviceId": "mac-1",
            "deviceName": "Mac",
            "platform": "macOS",
            "supportedProtocolVersion": 999,
            "supportedProtocolVersions": {
              "minimum": 999,
              "maximum": 999
            },
            "appVersion": "9.9.9",
            "buildNumber": "999",
            "capabilities": ["appActivation"]
          }
        }
        """

        let decoded = try RemoteDockMessage.decode(from: Data(json.utf8))

        guard case let .hello(payload) = decoded else {
            return XCTFail("Expected hello message")
        }

        XCTAssertEqual(payload.appVersion, "9.9.9")
        XCTAssertFalse(payload.isProtocolCompatible)
    }

    func testRejectsUnsupportedEnvelopeVersionForNonHelloMessages() throws {
        let json = """
        {
          "type": "error",
          "version": 999,
          "payload": {
            "code": "bad",
            "message": "Bad message"
          }
        }
        """

        XCTAssertThrowsError(try RemoteDockMessage.decode(from: Data(json.utf8))) { error in
            XCTAssertEqual(error as? RemoteDockError, .unsupportedProtocolVersion(999))
        }
    }
}
