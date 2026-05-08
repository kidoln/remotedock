import Foundation
import RemoteDockProtocol

public enum TransportConnectionState: Equatable, Sendable {
    case idle
    case discovering
    case connecting(TransportPeer)
    case connected(TransportPeer)
    case reconnecting(TransportPeer)
    case disconnected(reason: String?)
    case failed(String)
}

public struct TransportPeer: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public enum TransportSessionError: Error, Equatable, Sendable {
    case notConnected
    case peerNotFound(String)
    case unsupportedRole(String)
    case unavailable(String)
}

public struct TransportEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case stateChanged(TransportConnectionState)
        case discoveredPeersChanged([TransportPeer])
        case messageReceived(RemoteDockMessage)
    }

    public var kind: Kind
    public var emittedAt: Date

    public init(kind: Kind, emittedAt: Date = Date()) {
        self.kind = kind
        self.emittedAt = emittedAt
    }
}

public enum RemoteDockMessage: Equatable, Sendable {
    case hello(HelloPayload)
    case pairRequest(PairRequestPayload)
    case pairApprove(PairApprovePayload)
    case appsSnapshot(AppsSnapshotPayload)
    case runningAppsSnapshot(RunningAppsSnapshotPayload)
    case clipboardSnapshot(ClipboardSnapshotPayload)
    case clipboardDelta(ClipboardDeltaPayload)
    case iconManifest(IconManifestPayload)
    case iconRequest(IconRequestPayload)
    case iconPayload(IconPayload)
    case activateAppCommand(ActivateAppCommandPayload)
    case pasteClipboardItemCommand(PasteClipboardItemCommandPayload)
    case commandResult(CommandResultPayload)
    case error(ErrorPayload)

    public var messageType: RemoteDockMessageType {
        switch self {
        case .hello:
            .hello
        case .pairRequest:
            .pairRequest
        case .pairApprove:
            .pairApprove
        case .appsSnapshot:
            .appsSnapshot
        case .runningAppsSnapshot:
            .runningAppsSnapshot
        case .clipboardSnapshot:
            .clipboardSnapshot
        case .clipboardDelta:
            .clipboardDelta
        case .iconManifest:
            .iconManifest
        case .iconRequest:
            .iconRequest
        case .iconPayload:
            .iconPayload
        case .activateAppCommand:
            .activateAppCommand
        case .pasteClipboardItemCommand:
            .pasteClipboardItemCommand
        case .commandResult:
            .commandResult
        case .error:
            .error
        }
    }
}

public protocol TransportSession: Sendable {
    var state: TransportConnectionState { get async }
    var discoveredPeers: [TransportPeer] { get async }
    var events: AsyncStream<TransportEvent> { get async }

    func startDiscovery() async
    func connect(to peer: TransportPeer, pairingCode: String?) async throws
    func disconnect() async
    func reconnect(pairingCode: String?) async throws
    func send(_ message: RemoteDockMessage) async throws
}

public extension TransportSession {
    func connect(to peer: TransportPeer) async throws {
        try await connect(to: peer, pairingCode: nil)
    }

    func reconnect() async throws {
        try await reconnect(pairingCode: nil)
    }
}
