#if canImport(MultipeerConnectivity)
import Foundation
import MultipeerConnectivity
import RemoteDockProtocol

public enum MultipeerTransportRole: Sendable {
    case advertiser
    case browser
}

public final class MultipeerTransportSession: NSObject, @unchecked Sendable, TransportSession {
    private let role: MultipeerTransportRole
    private let serviceType: String
    private let localPeerID: MCPeerID
    private let session: MCSession
    private let queue = DispatchQueue(label: "remote-dock.multipeer-transport")

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var currentState: TransportConnectionState = .idle
    private var discoveredPeerIDsById: [String: MCPeerID] = [:]
    private var peers: [TransportPeer] = []
    private var lastConnectedPeerID: MCPeerID?

    private let stream: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation

    public var events: AsyncStream<TransportEvent> {
        get async { stream }
    }

    public var state: TransportConnectionState {
        get async { queue.sync { currentState } }
    }

    public var discoveredPeers: [TransportPeer] {
        get async { queue.sync { peers } }
    }

    public init(
        role: MultipeerTransportRole,
        serviceType: String = "erdock",
        displayName: String = "Remote Dock"
    ) {
        self.role = role
        self.serviceType = serviceType
        self.localPeerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)

        var localContinuation: AsyncStream<TransportEvent>.Continuation!
        self.stream = AsyncStream<TransportEvent> { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation

        super.init()

        session.delegate = self

        switch role {
        case .advertiser:
            let advertiser = MCNearbyServiceAdvertiser(
                peer: localPeerID,
                discoveryInfo: nil,
                serviceType: serviceType
            )
            advertiser.delegate = self
            self.advertiser = advertiser
        case .browser:
            let browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
            browser.delegate = self
            self.browser = browser
        }
    }

    deinit {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        continuation.finish()
    }

    public func startDiscovery() async {
        switch role {
        case .advertiser:
            advertiser?.startAdvertisingPeer()
        case .browser:
            browser?.startBrowsingForPeers()
        }
        setState(.discovering)
        emit(.discoveredPeersChanged(await discoveredPeers))
    }

    public func connect(to peer: TransportPeer) async throws {
        guard role == .browser else {
            throw TransportSessionError.unsupportedRole("Only browser sessions can initiate a connection.")
        }
        guard let peerID = queue.sync(execute: { discoveredPeerIDsById[peer.id] }) else {
            throw TransportSessionError.peerNotFound(peer.displayName)
        }

        setState(.connecting(peer))
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    public func disconnect() async {
        session.disconnect()
        setState(.disconnected(reason: nil))
    }

    public func reconnect() async throws {
        guard role == .browser else {
            await startDiscovery()
            return
        }
        guard let peerID = queue.sync(execute: { lastConnectedPeerID }) else {
            throw TransportSessionError.peerNotFound("No previously connected peer.")
        }

        let peer = remember(peerID)
        setState(.reconnecting(peer))
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    public func send(_ message: RemoteDockMessage) async throws {
        guard !session.connectedPeers.isEmpty else {
            throw TransportSessionError.notConnected
        }

        do {
            let data = try message.encodedData()
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch let error as TransportSessionError {
            throw error
        } catch {
            throw TransportSessionError.unavailable(error.localizedDescription)
        }
    }

    private func remember(_ peerID: MCPeerID) -> TransportPeer {
        let peer = TransportPeer(id: peerID.displayName, displayName: peerID.displayName)
        let nextPeers = queue.sync {
            discoveredPeerIDsById[peer.id] = peerID
            peers = discoveredPeerIDsById.values
                .map { TransportPeer(id: $0.displayName, displayName: $0.displayName) }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            return peers
        }
        emit(.discoveredPeersChanged(nextPeers))
        return peer
    }

    private func forget(_ peerID: MCPeerID) {
        let nextPeers = queue.sync {
            discoveredPeerIDsById.removeValue(forKey: peerID.displayName)
            peers = discoveredPeerIDsById.values
                .map { TransportPeer(id: $0.displayName, displayName: $0.displayName) }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            return peers
        }
        emit(.discoveredPeersChanged(nextPeers))
    }

    private func setState(_ state: TransportConnectionState) {
        queue.sync {
            currentState = state
        }
        emit(.stateChanged(state))
    }

    private func emit(_ kind: TransportEvent.Kind) {
        continuation.yield(TransportEvent(kind: kind))
    }
}

extension MultipeerTransportSession: MCNearbyServiceBrowserDelegate {
    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        _ = remember(peerID)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        forget(peerID)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        setState(.failed(error.localizedDescription))
    }
}

extension MultipeerTransportSession: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let peer = remember(peerID)
        setState(.connecting(peer))
        invitationHandler(true, session)
    }

    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        setState(.failed(error.localizedDescription))
    }
}

extension MultipeerTransportSession: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peer = remember(peerID)

        switch state {
        case .notConnected:
            setState(.disconnected(reason: "\(peer.displayName) disconnected"))
        case .connecting:
            setState(.connecting(peer))
        case .connected:
            queue.sync {
                lastConnectedPeerID = peerID
            }
            setState(.connected(peer))
        @unknown default:
            setState(.failed("Unknown MultipeerConnectivity state."))
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            emit(.messageReceived(try RemoteDockMessage.decode(from: data)))
        } catch {
            emit(.messageReceived(.error(ErrorPayload(
                code: "decode_failed",
                message: error.localizedDescription
            ))))
        }
    }

    public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}
#endif
