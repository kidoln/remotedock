import Foundation
import RemoteDockTransport

@MainActor
final class PeerSessionManager: ObservableObject {
    @Published private(set) var currentState: TransportConnectionState = .idle
    @Published private(set) var discoveredPeers: [TransportPeer] = []

    private let session = MockTransportSession()

    var events: AsyncStream<TransportEvent> {
        get async { await session.events }
    }

    func start() async {
        await session.startDiscovery()
        currentState = await session.state
        discoveredPeers = await session.discoveredPeers
    }

    func send(_ message: RemoteDockMessage) async throws {
        try await session.send(message)
    }
}
