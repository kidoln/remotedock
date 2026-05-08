import Foundation
import RemoteDockProtocol

public actor MockTransportSession: TransportSession {
    private var currentState: TransportConnectionState = .idle
    private var peers: [TransportPeer]
    private var lastConnectedPeer: TransportPeer?
    private var sentMessagesStorage: [RemoteDockMessage] = []
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

    public var sentMessages: [RemoteDockMessage] {
        sentMessagesStorage
    }

    public init(peers: [TransportPeer] = []) {
        self.peers = peers
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

    public func setDiscoveredPeers(_ peers: [TransportPeer]) async {
        self.peers = peers
        emit(.discoveredPeersChanged(peers))
    }

    public func connect(to peer: TransportPeer, pairingCode: String? = nil) async throws {
        await setState(.connecting(peer))
        lastConnectedPeer = peer
        await setState(.connected(peer))
    }

    public func disconnect() async {
        await setState(.disconnected(reason: nil))
    }

    public func reconnect(pairingCode: String? = nil) async throws {
        guard let lastConnectedPeer else {
            await setState(.failed("No previous peer to reconnect."))
            return
        }
        await setState(.reconnecting(lastConnectedPeer))
        await setState(.connected(lastConnectedPeer))
    }

    public func send(_ message: RemoteDockMessage) async throws {
        sentMessagesStorage.append(message)
    }

    public func injectReceivedMessage(_ message: RemoteDockMessage) async {
        emit(.messageReceived(message))
    }

    private func setState(_ state: TransportConnectionState) async {
        currentState = state
        emit(.stateChanged(state))
    }

    private func emit(_ kind: TransportEvent.Kind) {
        continuation.yield(TransportEvent(kind: kind))
    }
}
