import XCTest
import RemoteDockCore
@testable import RemoteDockProtocol

final class ProtocolEnvelopeTests: XCTestCase {
    func testEncodesAndDecodesTypedEnvelope() throws {
        let payload = HelloPayload(
            deviceId: "ios-1",
            deviceName: "iPhone",
            platform: .iOS,
            appVersion: "0.1.0",
            buildNumber: "1",
            capabilities: [.appActivation]
        )
        let envelope = ProtocolEnvelope(type: .hello, payload: payload)

        let data = try RemoteDockProtocolCodec.encode(envelope)
        let decoded = try RemoteDockProtocolCodec.decode(
            HelloPayload.self,
            from: data,
            expectedType: .hello
        )

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(decoded.payload.supportedProtocolVersions, ProtocolVersion.supportedRange)
        XCTAssertEqual(decoded.payload.appVersion, "0.1.0")
        XCTAssertEqual(decoded.payload.buildNumber, "1")
    }

    func testRejectsUnexpectedMessageType() throws {
        let envelope = ProtocolEnvelope(
            type: .error,
            payload: ErrorPayload(code: "bad", message: "Bad message")
        )
        let data = try RemoteDockProtocolCodec.encode(envelope)

        XCTAssertThrowsError(
            try RemoteDockProtocolCodec.decode(ErrorPayload.self, from: data, expectedType: .hello)
        ) { error in
            XCTAssertEqual(
                error as? ProtocolDecodingError,
                .unexpectedType(expected: .hello, actual: .error)
            )
        }
    }

    func testDecodesLegacyPasteCommandWithoutRichRepresentations() throws {
        let json = """
        {
          "type": "pasteClipboardItemCommand",
          "version": 1,
          "payload": {
            "commandId": "paste-1",
            "issuedAt": "1970-01-01T00:00:12Z",
            "clipboardItemId": "clipboard-1",
            "plainText": "legacy"
          }
        }
        """

        let envelope = try RemoteDockProtocolCodec.decode(
            PasteClipboardItemCommandPayload.self,
            from: Data(json.utf8),
            expectedType: .pasteClipboardItemCommand
        )

        XCTAssertEqual(envelope.payload.plainText, "legacy")
        XCTAssertEqual(envelope.payload.richRepresentations, [])
        XCTAssertEqual(envelope.payload.contentType, .text)
    }

    func testDecodesLegacyHelloWithoutVersionRangeOrAppVersion() throws {
        let json = """
        {
          "type": "hello",
          "version": 1,
          "payload": {
            "deviceId": "ios-1",
            "deviceName": "iPhone",
            "platform": "iOS",
            "supportedProtocolVersion": 1,
            "capabilities": ["appActivation"]
          }
        }
        """

        let envelope = try RemoteDockProtocolCodec.decode(
            HelloPayload.self,
            from: Data(json.utf8),
            expectedType: .hello
        )

        XCTAssertEqual(envelope.payload.supportedProtocolVersion, 1)
        XCTAssertEqual(envelope.payload.supportedProtocolVersions, ProtocolVersionRange(minimum: 1, maximum: 1))
        XCTAssertNil(envelope.payload.appVersion)
        XCTAssertNil(envelope.payload.buildNumber)
    }

    func testCalculatesHighestCommonProtocolVersion() {
        let peerRange = ProtocolVersionRange(minimum: 1, maximum: 3)

        XCTAssertEqual(
            ProtocolVersionRange(minimum: 1, maximum: 2).highestCommonVersion(with: peerRange),
            2
        )
        XCTAssertNil(ProtocolVersionRange(minimum: 4, maximum: 5).highestCommonVersion(with: peerRange))
    }

    func testRejectsUnsupportedVersionByDefault() throws {
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

        XCTAssertThrowsError(
            try RemoteDockProtocolCodec.decode(ErrorPayload.self, from: Data(json.utf8), expectedType: .error)
        ) { error in
            XCTAssertEqual(error as? RemoteDockError, .unsupportedProtocolVersion(999))
        }
    }

    func testAllowsUnsupportedVersionWhenRequested() throws {
        let json = """
        {
          "type": "hello",
          "version": 999,
          "payload": {
            "deviceId": "ios-1",
            "deviceName": "iPhone",
            "platform": "iOS",
            "supportedProtocolVersion": 999,
            "supportedProtocolVersions": {
              "minimum": 999,
              "maximum": 999
            },
            "capabilities": ["appActivation"]
          }
        }
        """

        let envelope = try RemoteDockProtocolCodec.decode(
            HelloPayload.self,
            from: Data(json.utf8),
            expectedType: .hello,
            allowUnsupportedEnvelopeVersion: true
        )

        XCTAssertFalse(envelope.payload.isProtocolCompatible)
        XCTAssertNil(envelope.payload.highestCompatibleProtocolVersion)
    }
}
