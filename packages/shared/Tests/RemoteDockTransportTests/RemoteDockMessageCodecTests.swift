import XCTest
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
}
