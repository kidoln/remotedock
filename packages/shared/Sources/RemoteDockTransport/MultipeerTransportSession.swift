#if canImport(MultipeerConnectivity)
import Foundation
import MultipeerConnectivity
import RemoteDockProtocol

public enum MultipeerTransportRole: Sendable {
    case advertiser
    case browser
}

private struct MultipeerInvitationContext: Codable {
    var pairingCode: String?
}

public final class MultipeerTransportSession: NSObject, @unchecked Sendable, TransportSession {
    private let role: MultipeerTransportRole
    private let serviceType: String
    private let localPeerID: MCPeerID
    private var session: MCSession
    private let pairingCodeValidator: (@Sendable (String?) -> Bool)?
    private let queue = DispatchQueue(label: "remote-dock.multipeer-transport")

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var currentState: TransportConnectionState = .idle
    private var discoveredPeerIDsById: [String: MCPeerID] = [:]
    private var peerIdsByObjectID: [ObjectIdentifier: String] = [:]
    private var peers: [TransportPeer] = []
    private var lastConnectedPeerID: MCPeerID?
    private var lastConnectedPeerDisplayName: String?

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
        displayName: String = "Remote Dock",
        discoveryInfo: [String: String]? = nil,
        pairingCodeValidator: (@Sendable (String?) -> Bool)? = nil
    ) {
        self.role = role
        self.serviceType = serviceType
        self.localPeerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.pairingCodeValidator = pairingCodeValidator

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
                discoveryInfo: discoveryInfo,
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
            restartBrowsing(clearPeers: false)
        }
        setState(.discovering)
        emit(.discoveredPeersChanged(await discoveredPeers))
    }

    public func connect(to peer: TransportPeer, pairingCode: String? = nil) async throws {
        guard role == .browser else {
            throw TransportSessionError.unsupportedRole("Only browser sessions can initiate a connection.")
        }
        guard let peerID = queue.sync(execute: { discoveredPeerIDsById[peer.id] }) else {
            throw TransportSessionError.peerNotFound(peer.displayName)
        }

        resetSession()
        setState(.connecting(peer))
        browser?.invitePeer(peerID, to: session, withContext: invitationContextData(pairingCode: pairingCode), timeout: 10)
    }

    public func disconnect() async {
        session.disconnect()
        resetSession()
        setState(.disconnected(reason: nil))
    }

    public func reconnect(pairingCode: String? = nil) async throws {
        guard role == .browser else {
            await startDiscovery()
            return
        }

        let targetDisplayName = queue.sync {
            lastConnectedPeerDisplayName ?? lastConnectedPeerID?.displayName
        }
        guard let targetDisplayName else {
            await startDiscovery()
            throw TransportSessionError.peerNotFound("No previously connected peer.")
        }

        restartBrowsing(clearPeers: true)
        setState(.discovering)

        guard let peerID = await waitForPeer(displayName: targetDisplayName, timeout: .seconds(6)) else {
            throw TransportSessionError.peerNotFound(targetDisplayName)
        }

        let peer = remember(peerID)
        resetSession()
        setState(.reconnecting(peer))
        browser?.invitePeer(peerID, to: session, withContext: invitationContextData(pairingCode: pairingCode), timeout: 10)
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

    private func remember(_ peerID: MCPeerID, discoveryInfo: [String: String]? = nil) -> TransportPeer {
        let nextPeers = queue.sync {
            let objectID = ObjectIdentifier(peerID)
            let peerId = discoveryInfo?["macId"] ??
                peerIdsByObjectID[objectID] ??
                "\(peerID.displayName)#\(UUID().uuidString)"
            peerIdsByObjectID[objectID] = peerId
            discoveredPeerIDsById[peerId] = peerID
            rebuildPeers()
            return peers
        }
        let peer = TransportPeer(id: peerId(for: peerID), displayName: peerID.displayName)
        emit(.discoveredPeersChanged(nextPeers))
        return peer
    }

    private func forget(_ peerID: MCPeerID) {
        let nextPeers = queue.sync {
            let objectID = ObjectIdentifier(peerID)
            if let peerId = peerIdsByObjectID.removeValue(forKey: objectID),
               discoveredPeerIDsById[peerId] == peerID {
                discoveredPeerIDsById.removeValue(forKey: peerId)
            }
            rebuildPeers()
            return peers
        }
        emit(.discoveredPeersChanged(nextPeers))
    }

    private func peerId(for peerID: MCPeerID) -> String {
        queue.sync {
            peerIdsByObjectID[ObjectIdentifier(peerID)] ?? peerID.displayName
        }
    }

    private func peer(displayName: String) -> MCPeerID? {
        return discoveredPeerIDsById.values.first {
            $0.displayName == displayName
        }
    }

    private func waitForPeer(displayName: String, timeout: Duration) async -> MCPeerID? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if let peerID = queue.sync(execute: { peer(displayName: displayName) }) {
                return peerID
            }

            try? await Task.sleep(for: .milliseconds(250))
        }

        return queue.sync(execute: { peer(displayName: displayName) })
    }

    private func rebuildPeers() {
        peers = discoveredPeerIDsById
            .map { id, peerID in
                TransportPeer(id: id, displayName: peerID.displayName)
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func clearPeers() -> [TransportPeer] {
        queue.sync {
            discoveredPeerIDsById.removeAll()
            peerIdsByObjectID.removeAll()
            peers.removeAll()
            return peers
        }
    }

    private func restartBrowsing(clearPeers shouldClearPeers: Bool) {
        guard role == .browser else {
            return
        }

        browser?.stopBrowsingForPeers()
        if shouldClearPeers {
            emit(.discoveredPeersChanged(clearPeers()))
        }

        let browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
    }

    private func resetSession() {
        let oldSession = session
        oldSession.delegate = nil
        oldSession.disconnect()
        session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    private func invitationContextData(pairingCode: String?) -> Data? {
        guard let pairingCode else {
            return nil
        }

        return try? JSONEncoder().encode(MultipeerInvitationContext(pairingCode: pairingCode))
    }

    private func pairingCode(from context: Data?) -> String? {
        guard let context else {
            return nil
        }

        return try? JSONDecoder().decode(MultipeerInvitationContext.self, from: context).pairingCode
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
        _ = remember(peerID, discoveryInfo: info)
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

        if let pairingCodeValidator, !pairingCodeValidator(pairingCode(from: context)) {
            setState(.failed("配对码不正确"))
            invitationHandler(false, nil)
            return
        }

        resetSession()
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
                lastConnectedPeerDisplayName = peerID.displayName
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
