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
}
