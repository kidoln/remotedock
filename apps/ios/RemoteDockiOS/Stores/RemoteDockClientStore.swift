import Foundation
import RemoteDockCore
import RemoteDockProtocol
import RemoteDockTransport
import SwiftUI

@MainActor
final class RemoteDockClientStore: ObservableObject {
    @Published var discovery = DiscoveryStore()
    @Published var dock = DockStore()
    @Published var runningApps = RunningAppsStore()
    @Published var clipboard = ClipboardStore()
    @Published var settings = SettingsStore()
    @Published private(set) var lastCommandResult: CommandResultPayload?

    private let transport = MockTransportSession(
        peers: [TransportPeer(id: "mock-mac", displayName: "Kido Mac")]
    )
    private lazy var commandDispatcher = CommandDispatcher(transport: transport)

    init() {
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
}
