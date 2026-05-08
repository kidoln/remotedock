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
    @Published private(set) var connectionErrorMessage: String?

    private let deviceId: String
    private let deviceName: String
    private let transport: any TransportSession
    private lazy var commandDispatcher = CommandDispatcher(transport: transport)
    private var reconnectTask: Task<Void, Never>?
    private var allowsAutomaticReconnect = true

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
        settings.savedPairingCode = UserDefaults.standard.string(forKey: Self.savedPairingCodeDefaultsKey)
        settings.pairingCodeInput = settings.savedPairingCode ?? ""

        dock.apps = MockBootstrap.pinnedApps
        runningApps.apps = MockBootstrap.runningApps
        clipboard.items = MockBootstrap.clipboardItems
        Task {
            await start()
        }
    }

    var shouldShowPairingGate: Bool {
        if case .connected = discovery.connectionState {
            return false
        }

        return true
    }

    var isConnected: Bool {
        if case .connected = discovery.connectionState {
            return true
        }

        return false
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

    func connectToPreferredMacIfPossible(manuallyTriggered: Bool = false) {
        guard normalizedPairingCodeInput.count == 4 else {
            if manuallyTriggered {
                connectionErrorMessage = "请输入 Mac 上显示的四位配对码。"
            }
            return
        }

        guard canStartConnection else {
            return
        }

        guard let peer = preferredDiscoveredMac else {
            connectionErrorMessage = manuallyTriggered ? "正在搜索同一网络附近的 Mac。" : nil
            return
        }

        connect(to: peer)
    }

    func connect(to peer: TransportPeer) {
        let pairingCode = normalizedPairingCodeInput
        guard pairingCode.count == 4 else {
            connectionErrorMessage = "请输入 Mac 上显示的四位配对码。"
            discovery.connectionState = .failed("请输入四位配对码")
            return
        }

        allowsAutomaticReconnect = true
        Task {
            do {
                try await transport.connect(to: peer, pairingCode: pairingCode)
                connectionErrorMessage = nil
            } catch {
                connectionErrorMessage = error.localizedDescription
                discovery.connectionState = .failed(error.localizedDescription)
            }
            discovery.connectionState = await transport.state
            settings.selectedMacId = peer.id
        }
    }

    func reconnect() {
        let inputPairingCode = normalizedPairingCodeInput
        let pairingCode = inputPairingCode.count == 4 ? inputPairingCode : settings.savedPairingCode ?? ""
        guard pairingCode.count == 4 else {
            connectionErrorMessage = "请输入 Mac 上显示的四位配对码。"
            discovery.connectionState = .failed("请输入四位配对码")
            return
        }

        allowsAutomaticReconnect = true
        Task {
            do {
                try await transport.reconnect(pairingCode: pairingCode)
                connectionErrorMessage = nil
            } catch {
                connectionErrorMessage = error.localizedDescription
                discovery.connectionState = .failed(error.localizedDescription)
            }
            discovery.connectionState = await transport.state
        }
    }

    func disconnectFromMac() {
        allowsAutomaticReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        connectionErrorMessage = nil
        pairingCode = nil
        settings.pairingCodeInput = ""
        discovery.connectionState = .disconnected(reason: nil)

        Task {
            await transport.disconnect()
            discovery.connectionState = await transport.state
        }
    }

    func updatePairingCodeInput(_ value: String) {
        settings.pairingCodeInput = String(value.filter(\.isNumber).prefix(4))
        if settings.pairingCodeInput.count < 4 {
            connectionErrorMessage = nil
        }
    }

    private func handleTransportEvent(_ event: TransportEvent) async {
        switch event.kind {
        case let .stateChanged(state):
            discovery.connectionState = state
            if case let .connected(peer) = state {
                settings.selectedMacId = peer.id
                connectionErrorMessage = nil
                await sendPairingHandshake()
            } else if case .disconnected = state {
                scheduleReconnectIfNeeded()
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
            settings.savedPairingCode = payload.pairingCode
            settings.pairingCodeInput = payload.pairingCode
            Self.savePairingCode(payload.pairingCode)
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

    private var normalizedPairingCodeInput: String {
        String(settings.pairingCodeInput.filter(\.isNumber).prefix(4))
    }

    private var canStartConnection: Bool {
        switch discovery.connectionState {
        case .connected, .connecting, .reconnecting:
            return false
        default:
            return true
        }
    }

    private var preferredDiscoveredMac: TransportPeer? {
        if let selectedMacId = settings.selectedMacId,
           let selectedPeer = discovery.availableMacs.first(where: { $0.id == selectedMacId }) {
            return selectedPeer
        }

        return discovery.availableMacs.first
    }

    private func scheduleReconnectIfNeeded() {
        guard allowsAutomaticReconnect else {
            return
        }
        guard reconnectTask == nil else {
            return
        }
        guard let pairingCode = settings.savedPairingCode, pairingCode.count == 4 else {
            return
        }

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                self?.reconnectTask = nil
                self?.reconnect()
            }
        }
    }

    private static let savedPairingCodeDefaultsKey = "remoteDock.iOS.savedPairingCode"

    private static func savePairingCode(_ pairingCode: String) {
        UserDefaults.standard.set(pairingCode, forKey: savedPairingCodeDefaultsKey)
    }
}
