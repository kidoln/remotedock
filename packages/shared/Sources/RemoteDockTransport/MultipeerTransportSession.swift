#if canImport(MultipeerConnectivity)
import Foundation
import MultipeerConnectivity
import RemoteDockProtocol

public actor MultipeerTransportSession: TransportSession {
    private let serviceType: String
    private let localPeerID: MCPeerID
    private var currentState: TransportConnectionState = .idle
    private var peers: [TransportPeer] = []
    private let stream: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation

    public nonisolated var events: AsyncStream<TransportEvent> {
        get async { stream }
    }

    public var state: TransportConnectionState {
        get async { currentState }
    }

    public var discoveredPeers: [TransportPeer] {
        get async { peers }
    }

    public init(
        serviceType: String = "erdock",
        displayName: String = "Remote Dock"
    ) {
        self.serviceType = serviceType
        self.localPeerID = MCPeerID(displayName: displayName)

        var localContinuation: AsyncStream<TransportEvent>.Continuation!
        self.stream = AsyncStream<TransportEvent> { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
    }

    deinit {
        continuation.finish()
    }

    public func startDiscovery() async {
        await setState(.discovering)
        emit(.discoveredPeersChanged(peers))
    }

    public func connect(to peer: TransportPeer) async throws {
        await setState(.connecting(peer))
        await setState(.failed("Multipeer adapter scaffold is not wired to MCSession yet."))
    }

    public func disconnect() async {
        await setState(.disconnected(reason: nil))
    }

    public func reconnect() async throws {
        await setState(.failed("Reconnect is not available until MCSession wiring is implemented."))
    }

    public func send(_ message: RemoteDockMessage) async throws {
        throw TransportSessionError.notConnected
    }

    private func setState(_ state: TransportConnectionState) async {
        currentState = state
        emit(.stateChanged(state))
    }

    private func emit(_ kind: TransportEvent.Kind) {
        continuation.yield(TransportEvent(kind: kind))
    }
}

public enum TransportSessionError: Error, Equatable, Sendable {
    case notConnected
}
#endif
