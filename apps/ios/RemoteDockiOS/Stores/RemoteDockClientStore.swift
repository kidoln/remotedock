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
    private let injectedTransport: (any TransportSession)?
    private var transport: (any TransportSession)?
    private var transportCreationTask: Task<any TransportSession, Never>?
    private var startTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var allowsAutomaticReconnect = true
    private var hasCompletedInitialDiscovery = false

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
        self.injectedTransport = transport
        self.transport = transport
        settings.savedPairingCode = UserDefaults.standard.string(forKey: Self.savedPairingCodeDefaultsKey)
        settings.pairingCodeInput = settings.savedPairingCode ?? ""
        settings.iconGridCount = Self.loadIconGridCount()
        settings.clipboardFontSize = Self.loadClipboardFontSize()
        settings.movePastedClipboardItemToTop = Self.loadMovePastedClipboardItemToTop()
        settings.moveActivatedRunningAppToTop = Self.loadMoveActivatedRunningAppToTop()

        dock.apps = MockBootstrap.pinnedApps
        runningApps.apps = MockBootstrap.runningApps
        clipboard.items = MockBootstrap.clipboardItems
    }

    deinit {
        transportCreationTask?.cancel()
        startTask?.cancel()
        reconnectTask?.cancel()
    }

    func iconImage(for app: PinnedApp) -> UIImage? {
        guard let hash = app.iconAssetHash else {
            return nil
        }

        return dock.iconImagesByHash[hash]
    }

    func iconImage(for app: RunningApp) -> UIImage? {
        guard let hash = app.iconAssetHash else {
            return nil
        }

        return runningApps.iconImagesByHash[hash] ?? dock.iconImagesByHash[hash]
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

    func startIfNeeded() {
        guard startTask == nil else {
            return
        }

        startTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled else {
                return
            }

            let transport = await self.ensureTransport()
            await self.refreshDiscovery(using: transport, restartBrowsing: true)

            for await event in await transport.events {
                if Task.isCancelled {
                    break
                }
                await self.handleTransportEvent(event)
            }
        }
    }

    func applicationDidBecomeActive() {
        startIfNeeded()

        guard hasCompletedInitialDiscovery else {
            return
        }

        guard shouldRefreshDiscoveryOnActivation else {
            return
        }

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else {
                return
            }

            let transport = await self.ensureTransport()
            await self.refreshDiscovery(using: transport, restartBrowsing: true)
        }
    }

    func activate(_ app: PinnedApp) {
        Task { [weak self] in
            guard let self else { return }
            let transport = await self.ensureTransport()
            let dispatcher = CommandDispatcher(transport: transport)
            try? await Self.performTransportOperation {
                try await dispatcher.activate(app)
            }
            dock.lastActivatedAppId = app.id
        }
    }

    func activate(_ app: RunningApp) {
        markRunningAppAsActivated(app)

        Task { [weak self] in
            guard let self else { return }
            let transport = await self.ensureTransport()
            let dispatcher = CommandDispatcher(transport: transport)
            try? await Self.performTransportOperation {
                try await dispatcher.activate(app)
            }
        }
    }

    func paste(_ item: ClipboardItem) {
        markClipboardItemAsPasted(item)

        Task { [weak self] in
            guard let self else { return }
            let transport = await self.ensureTransport()
            let dispatcher = CommandDispatcher(transport: transport)
            try? await Self.performTransportOperation {
                try await dispatcher.paste(item)
            }
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
        discovery.connectionState = .connecting(peer)
        Task { [weak self] in
            guard let self else { return }
            let transport = await self.ensureTransport()
            do {
                try await Self.performTransportOperation {
                    try await transport.connect(to: peer, pairingCode: pairingCode)
                }
                connectionErrorMessage = nil
                discovery.connectionState = await transport.state
                settings.selectedMacId = peer.id
            } catch {
                connectionErrorMessage = error.localizedDescription
                discovery.connectionState = .failed(error.localizedDescription)
            }
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
        if let peer = preferredDiscoveredMac {
            discovery.connectionState = .reconnecting(peer)
        }
        Task { [weak self] in
            guard let self else { return }
            let transport = await self.ensureTransport()
            do {
                try await Self.performTransportOperation {
                    try await transport.reconnect(pairingCode: pairingCode)
                }
                connectionErrorMessage = nil
                discovery.connectionState = await transport.state
            } catch {
                connectionErrorMessage = error.localizedDescription
                discovery.connectionState = .failed(error.localizedDescription)
            }
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

        Task { [weak self] in
            guard let self else { return }
            let transport = await self.ensureTransport()
            await Self.performTransportOperation {
                await transport.disconnect()
            }
            discovery.connectionState = await transport.state
        }
    }

    func updatePairingCodeInput(_ value: String) {
        settings.pairingCodeInput = String(value.filter(\.isNumber).prefix(4))
        if settings.pairingCodeInput.count < 4 {
            connectionErrorMessage = nil
        }
    }

    func updateIconGridCount(_ value: PhoneIconGridCount) {
        settings.iconGridCount = value
        UserDefaults.standard.set(value.rawValue, forKey: Self.iconGridCountDefaultsKey)
    }

    func updateClipboardFontSize(_ value: PhoneClipboardFontSize) {
        settings.clipboardFontSize = value
        UserDefaults.standard.set(value.rawValue, forKey: Self.clipboardFontSizeDefaultsKey)
    }

    func updateMovePastedClipboardItemToTop(_ value: Bool) {
        settings.movePastedClipboardItemToTop = value
        UserDefaults.standard.set(value, forKey: Self.movePastedClipboardItemToTopDefaultsKey)
    }

    func updateMoveActivatedRunningAppToTop(_ value: Bool) {
        settings.moveActivatedRunningAppToTop = value
        UserDefaults.standard.set(value, forKey: Self.moveActivatedRunningAppToTopDefaultsKey)
    }

    func clearLocalClipboardHistory() {
        clipboard.items.removeAll()
        clipboard.searchText = ""
        clipboard.lastPastedItemId = nil
    }

    private func handleTransportEvent(_ event: TransportEvent) async {
        switch event.kind {
        case let .stateChanged(state):
            applyTransportState(state)
            if case let .connected(peer) = state {
                settings.selectedMacId = peer.id
                connectionErrorMessage = nil
                await sendPairingHandshake()
            } else if case .disconnected = state {
                scheduleReconnectIfNeeded()
            }
        case let .discoveredPeersChanged(peers):
            discovery.availableMacs = peers
            connectToPreferredMacIfPossible()
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
            requestMissingIcons(for: payload.apps.compactMap(\.iconAssetHash))
        case let .runningAppsSnapshot(payload):
            applyRunningAppsSnapshot(payload.apps)
            requestMissingIcons(for: payload.apps.compactMap(\.iconAssetHash))
        case let .clipboardSnapshot(payload):
            clipboard.items = payload.items
        case let .clipboardDelta(payload):
            applyClipboardDelta(payload)
        case let .iconManifest(payload):
            requestMissingIcons(from: payload)
        case let .iconPayload(payload):
            applyIconPayload(payload)
        case let .commandResult(payload):
            lastCommandResult = payload
        default:
            break
        }
    }

    private func sendPairingHandshake() async {
        let transport = await ensureTransport()
        let hello = HelloPayload(
            deviceId: deviceId,
            deviceName: deviceName,
            platform: .iOS,
            capabilities: [.appActivation, .clipboardPaste, .iconSync]
        )
        try? await Self.performTransportOperation {
            try await transport.send(.hello(hello))
        }

        let pairRequest = PairRequestPayload(
            deviceId: deviceId,
            deviceName: deviceName,
            requestedAt: Date()
        )
        try? await Self.performTransportOperation {
            try await transport.send(.pairRequest(pairRequest))
        }
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
            clipboard.searchText = ""
            clipboard.lastPastedItemId = nil
        }
    }

    private func applyRunningAppsSnapshot(_ apps: [RunningApp]) {
        runningApps.lastActivatedAppId = apps.first(where: \.isActive)?.id

        guard !settings.moveActivatedRunningAppToTop else {
            runningApps.apps = apps
            return
        }

        guard !runningApps.apps.isEmpty else {
            runningApps.apps = apps
            return
        }

        var incomingAppsById: [String: RunningApp] = [:]
        for app in apps where incomingAppsById[app.id] == nil {
            incomingAppsById[app.id] = app
        }

        let existingAppIds = Set(runningApps.apps.map(\.id))
        let orderedExistingApps = runningApps.apps.compactMap { incomingAppsById[$0.id] }
        let newApps = apps.filter { !existingAppIds.contains($0.id) }

        runningApps.apps = orderedExistingApps + newApps
    }

    private func markClipboardItemAsPasted(_ item: ClipboardItem) {
        clipboard.lastPastedItemId = item.id

        guard settings.movePastedClipboardItemToTop,
              let index = clipboard.items.firstIndex(where: { $0.id == item.id }),
              index != clipboard.items.startIndex else {
            return
        }

        let pastedItem = clipboard.items.remove(at: index)
        clipboard.items.insert(pastedItem, at: clipboard.items.startIndex)
    }

    private func markRunningAppAsActivated(_ app: RunningApp) {
        runningApps.lastActivatedAppId = app.id
        runningApps.apps = runningApps.apps.map { runningApp in
            var updatedApp = runningApp
            updatedApp.isActive = runningApp.id == app.id
            return updatedApp
        }

        guard settings.moveActivatedRunningAppToTop,
              let index = runningApps.apps.firstIndex(where: { $0.id == app.id }),
              index != runningApps.apps.startIndex else {
            return
        }

        let activatedApp = runningApps.apps.remove(at: index)
        runningApps.apps.insert(activatedApp, at: runningApps.apps.startIndex)
    }

    private func requestMissingIcons(from payload: IconManifestPayload) {
        requestMissingIcons(for: payload.assets.map(\.hash))
    }

    private func requestMissingIcons(for hashes: [String]) {
        let knownHashes = Set(dock.iconImagesByHash.keys).union(runningApps.iconImagesByHash.keys)
        let missingHashes = Array(Set(hashes))
            .filter { !$0.isEmpty && !knownHashes.contains($0) }
            .sorted()

        guard !missingHashes.isEmpty else {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let transport = await self.ensureTransport()
            try? await Self.performTransportOperation {
                try await transport.send(.iconRequest(IconRequestPayload(hashes: missingHashes)))
            }
        }
    }

    private func applyIconPayload(_ payload: IconPayload) {
        guard let data = Data(base64Encoded: payload.base64PNGData),
              let image = UIImage(data: data) else {
            return
        }

        var updatedDock = dock
        updatedDock.iconImagesByHash[payload.asset.hash] = image
        dock = updatedDock

        var updatedRunningApps = runningApps
        updatedRunningApps.iconImagesByHash[payload.asset.hash] = image
        runningApps = updatedRunningApps
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

    private var shouldRefreshDiscoveryOnActivation: Bool {
        switch discovery.connectionState {
        case .connected, .connecting, .reconnecting:
            return false
        default:
            return true
        }
    }

    private func refreshDiscovery(using transport: any TransportSession, restartBrowsing: Bool) async {
        let snapshot = await Task.detached(priority: .userInitiated) {
            if restartBrowsing {
                await transport.startDiscovery()
            }
            return (state: await transport.state, peers: await transport.discoveredPeers)
        }.value

        applyTransportState(snapshot.state)
        discovery.availableMacs = snapshot.peers
        hasCompletedInitialDiscovery = true
        connectToPreferredMacIfPossible()
    }

    private func ensureTransport() async -> any TransportSession {
        if let transport {
            return transport
        }

        if let injectedTransport {
            transport = injectedTransport
            return injectedTransport
        }

        if let transportCreationTask {
            let transport = await transportCreationTask.value
            self.transport = transport
            return transport
        }

        let deviceName = deviceName
        let transportCreationTask = Task.detached(priority: .userInitiated) {
            MultipeerTransportSession(role: .browser, displayName: deviceName) as any TransportSession
        }
        self.transportCreationTask = transportCreationTask

        let transport = await transportCreationTask.value
        self.transport = transport
        self.transportCreationTask = nil
        return transport
    }

    private static func performTransportOperation<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            try await operation()
        }.value
    }

    private static func performTransportOperation<T: Sendable>(
        _ operation: @escaping @Sendable () async -> T
    ) async -> T {
        await Task.detached(priority: .userInitiated) {
            await operation()
        }.value
    }

    private func applyTransportState(_ state: TransportConnectionState) {
        guard shouldApplyTransportState(state) else {
            return
        }

        discovery.connectionState = state
    }

    private func shouldApplyTransportState(_ state: TransportConnectionState) -> Bool {
        switch (discovery.connectionState, state) {
        case (.connecting, .idle),
             (.connecting, .discovering),
             (.reconnecting, .idle),
             (.reconnecting, .discovering),
             (.connected, .idle),
             (.connected, .discovering):
            return false
        default:
            return true
        }
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
    private static let iconGridCountDefaultsKey = "remoteDock.iOS.iconGridCount"
    private static let clipboardFontSizeDefaultsKey = "remoteDock.iOS.clipboardFontSize"
    private static let movePastedClipboardItemToTopDefaultsKey = "remoteDock.iOS.movePastedClipboardItemToTop"
    private static let moveActivatedRunningAppToTopDefaultsKey = "remoteDock.iOS.moveActivatedRunningAppToTop"

    private static func savePairingCode(_ pairingCode: String) {
        UserDefaults.standard.set(pairingCode, forKey: savedPairingCodeDefaultsKey)
    }

    private static func loadIconGridCount() -> PhoneIconGridCount {
        let rawValue = UserDefaults.standard.integer(forKey: iconGridCountDefaultsKey)
        return PhoneIconGridCount(rawValue: rawValue) ?? .four
    }

    private static func loadClipboardFontSize() -> PhoneClipboardFontSize {
        let rawValue = UserDefaults.standard.integer(forKey: clipboardFontSizeDefaultsKey)
        return PhoneClipboardFontSize(rawValue: rawValue) ?? .small
    }

    private static func loadMovePastedClipboardItemToTop() -> Bool {
        guard UserDefaults.standard.object(forKey: movePastedClipboardItemToTopDefaultsKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: movePastedClipboardItemToTopDefaultsKey)
    }

    private static func loadMoveActivatedRunningAppToTop() -> Bool {
        guard UserDefaults.standard.object(forKey: moveActivatedRunningAppToTopDefaultsKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: moveActivatedRunningAppToTopDefaultsKey)
    }
}
