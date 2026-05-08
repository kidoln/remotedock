import XCTest
import RemoteDockProtocol
@testable import RemoteDockTransport

final class MockTransportSessionTests: XCTestCase {
    func testDiscoveryPublishesPeers() async {
        let peer = TransportPeer(id: "mac-1", displayName: "MacBook")
        let session = MockTransportSession(peers: [peer])

        await session.startDiscovery()

        let peers = await session.discoveredPeers
        let state = await session.state

        XCTAssertEqual(peers, [peer])
        XCTAssertEqual(state, .discovering)
    }

    func testConnectAndReconnectUpdateState() async throws {
        let peer = TransportPeer(id: "mac-1", displayName: "MacBook")
        let session = MockTransportSession(peers: [peer])

        try await session.connect(to: peer)
        var state = await session.state
        XCTAssertEqual(state, .connected(peer))

        await session.disconnect()
        state = await session.state
        XCTAssertEqual(state, .disconnected(reason: nil))

        try await session.reconnect()
        state = await session.state
        XCTAssertEqual(state, .connected(peer))
    }

    func testSendStoresMessage() async throws {
        let session = MockTransportSession()
        let payload = ErrorPayload(code: "test", message: "Test")

        try await session.send(.error(payload))

        let sentMessages = await session.sentMessages
        XCTAssertEqual(sentMessages, [.error(payload)])
    }
}
