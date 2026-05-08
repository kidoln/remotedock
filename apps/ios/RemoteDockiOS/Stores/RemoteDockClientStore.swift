import Foundation
import RemoteDockCore
import RemoteDockProtocol
import RemoteDockTransport
import SwiftUI
import UIKit

@MainActor
final class RemoteDockClientStore: ObservableObject {
    @Published var discovery = DiscoveryStore()
    @Published var dock = DockStore()
    @Published var runningApps = RunningAppsStore()
    @Published var clipboard = ClipboardStore()
    @Published var settings = SettingsStore()
    @Published private(set) var lastCommandResult: CommandResultPayload?
    @Published private(set) var pairingCode: String?

    private let deviceId: String
    private let deviceName: String
    private let transport: any TransportSession
    private lazy var commandDispatcher = CommandDispatcher(transport: transport)

    init(transport: (any TransportSession)? = nil) {
        let storedDeviceIdKey = "remoteDock.iOS.deviceId"
        if let storedDeviceId = UserDefaults.standard.string(forKey: storedDeviceIdKey) {
            self.deviceId = storedDeviceId
        } else {
            let newDeviceId = UUID().uuidString
            UserDefaults.standard.set(newDeviceId, forKey: storedDeviceIdKey)
            self.deviceId = newDeviceId
        }
        self.deviceName = UIDevice.current.name
        self.transport = transport ?? MultipeerTransportSession(role: .browser, displayName: UIDevice.current.name)

        dock.apps = MockBootstrap.pinnedApps
        runningApps.apps = MockBootstrap.runningApps
        clipboard.items = MockBootstrap.clipboardItems
        Task {
            await start()
        }
    }

    func start() async {
        await transport.startDiscovery()
        discovery.connectionState = await transport.state
        discovery.availableMacs = await transport.discoveredPeers

        for await event in await transport.events {
            await handleTransportEvent(event)
        }
    }

    func activate(_ app: PinnedApp) {
        Task {
            try? await commandDispatcher.activate(app)
            dock.lastActivatedAppId = app.id
        }
    }

    func activate(_ app: RunningApp) {
        Task {
            try? await commandDispatcher.activate(app)
            runningApps.lastActivatedAppId = app.id
        }
    }

    func paste(_ item: ClipboardItem) {
        Task {
            try? await commandDispatcher.paste(item)
            clipboard.lastPastedItemId = item.id
        }
    }

    func connect(to peer: TransportPeer) {
        Task {
            try? await transport.connect(to: peer)
            discovery.connectionState = await transport.state
            settings.selectedMacId = peer.id
        }
    }

    func reconnect() {
        Task {
            try? await transport.reconnect()
            discovery.connectionState = await transport.state
        }
    }

    private func handleTransportEvent(_ event: TransportEvent) async {
        switch event.kind {
        case let .stateChanged(state):
            discovery.connectionState = state
            if case let .connected(peer) = state {
                settings.selectedMacId = peer.id
                await sendPairingHandshake()
            }
        case let .discoveredPeersChanged(peers):
            discovery.availableMacs = peers
        case let .messageReceived(message):
            await handleMessage(message)
        }
    }

    private func handleMessage(_ message: RemoteDockMessage) async {
        switch message {
        case let .pairApprove(payload):
            pairingCode = payload.pairingCode
        case let .appsSnapshot(payload):
            dock.apps = payload.apps
        case let .runningAppsSnapshot(payload):
            runningApps.apps = payload.apps
        case let .clipboardSnapshot(payload):
            clipboard.items = payload.items
        case let .clipboardDelta(payload):
            applyClipboardDelta(payload)
        case let .commandResult(payload):
            lastCommandResult = payload
        default:
            break
        }
    }

    private func sendPairingHandshake() async {
        let hello = HelloPayload(
            deviceId: deviceId,
            deviceName: deviceName,
            platform: .iOS,
            capabilities: [.appActivation, .clipboardPaste]
        )
        try? await transport.send(.hello(hello))

        let pairRequest = PairRequestPayload(
            deviceId: deviceId,
            deviceName: deviceName,
            requestedAt: Date()
        )
        try? await transport.send(.pairRequest(pairRequest))
    }

    private func applyClipboardDelta(_ payload: ClipboardDeltaPayload) {
        switch payload.operation {
        case .inserted:
            guard let item = payload.item else { return }
            clipboard.items = ClipboardHistoryReducer.inserting(item, into: clipboard.items)
        case .deleted:
            guard let itemId = payload.itemId else { return }
            clipboard.items.removeAll { $0.id == itemId }
        case .cleared:
            clipboard.items.removeAll()
        }
    }
}
