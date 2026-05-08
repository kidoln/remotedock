import Foundation
import RemoteDockProtocol
import RemoteDockTransport

@MainActor
final class PeerSessionManager: ObservableObject {
    @Published private(set) var currentState: TransportConnectionState = .idle
    @Published private(set) var discoveredPeers: [TransportPeer] = []

    private let session: any TransportSession

    init(
        session: (any TransportSession)? = nil,
        macId: String? = nil,
        pairingCodeValidator: (@Sendable (String?) -> Bool)? = nil
    ) {
        self.session = session ?? MultipeerTransportSession(
            role: .advertiser,
            displayName: Host.current().localizedName ?? "Remote Dock Mac",
            discoveryInfo: macId.map { ["macId": $0] },
            pairingCodeValidator: pairingCodeValidator
        )
    }

    var events: AsyncStream<TransportEvent> {
        get async { await session.events }
    }

    func start() async {
        await session.startDiscovery()
        currentState = await session.state
        discoveredPeers = await session.discoveredPeers
    }

    func refreshState() async {
        currentState = await session.state
        discoveredPeers = await session.discoveredPeers
    }

    func send(_ message: RemoteDockMessage) async throws {
        try await session.send(message)
    }
}
