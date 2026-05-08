import XCTest
import RemoteDockCore
@testable import RemoteDockProtocol

final class ProtocolEnvelopeTests: XCTestCase {
    func testEncodesAndDecodesTypedEnvelope() throws {
        let payload = HelloPayload(
            deviceId: "ios-1",
            deviceName: "iPhone",
            platform: .iOS,
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
}
