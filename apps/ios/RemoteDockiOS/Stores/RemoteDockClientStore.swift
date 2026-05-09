import Foundation
import RemoteDockCore
import RemoteDockProtocol
import RemoteDockTransport
import SwiftUI
import UIKit

struct RemoteDockVersionMismatchNotice: Equatable, Identifiable {
    var mismatch: RemoteDockAppVersionMismatch
    var phoneVersion: String
    var macVersion: String

    var id: String {
        "\(mismatch)-\(phoneVersion)-\(macVersion)"
    }
}

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
    @Published private(set) var pairedMacAppVersion: String?
    @Published private(set) var versionMismatchNotice: RemoteDockVersionMismatchNotice?
    @Published private(set) var negotiatedProtocolVersion: Int?
    @Published private(set) var peerProtocolIsCompatible = true
    @Published private(set) var isBackgroundReconnecting = false

    private let deviceId: String
    private let deviceName: String
    private let injectedTransport: (any TransportSession)?
    private var transport: (any TransportSession)?
    private var transportCreationTask: Task<any TransportSession, Never>?
    private var startTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var backgroundReconnectTask: Task<Void, Never>?
    private var allowsAutomaticReconnect = true
    private var hasCompletedInitialDiscovery = false
    private var hasFailedBackgroundReconnect = false
    private var dismissedVersionMismatchNoticeID: String?

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
        let storedPairingCode = UserDefaults.standard.string(forKey: Self.savedPairingCodeDefaultsKey)
        settings.selectedMacId = UserDefaults.standard.string(forKey: Self.selectedMacIdDefaultsKey)
        settings.savedPairingCode = storedPairingCode
        settings.pairingCodeInput = settings.savedPairingCode ?? ""
        settings.remoteLanguage = Self.loadRemoteLanguage()
        settings.iconGridCount = Self.loadIconGridCount()
        settings.clipboardFontSize = Self.loadClipboardFontSize()
        settings.movePastedClipboardItemToTop = Self.loadMovePastedClipboardItemToTop()
        settings.moveActivatedRunningAppToTop = Self.loadMoveActivatedRunningAppToTop()
        isBackgroundReconnecting = Self.validPairingCode(from: storedPairingCode) != nil

        dock.apps = MockBootstrap.pinnedApps
        runningApps.apps = MockBootstrap.runningApps
        clipboard.items = MockBootstrap.clipboardItems
    }

    deinit {
        transportCreationTask?.cancel()
        startTask?.cancel()
        reconnectTask?.cancel()
        backgroundReconnectTask?.cancel()
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

    func sourceAppIconImage(for item: ClipboardItem) -> UIImage? {
        guard let hash = clipboardIconHash(for: item) else {
            return nil
        }

        return clipboard.sourceAppIconImagesByHash[hash] ??
            runningApps.iconImagesByHash[hash] ??
            dock.iconImagesByHash[hash]
    }

    var shouldShowPairingGate: Bool {
        if case .connected = discovery.connectionState {
            return false
        }

        if isBackgroundReconnecting {
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
            guard let self, !Task.isCancelled else {
                return
            }

            let transport = await self.ensureTransport()
            if self.validSavedPairingCode != nil {
                await self.startBackgroundReconnect(using: transport, initialDelay: .milliseconds(120))
            } else {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else {
                    return
                }

                await self.refreshDiscovery(using: transport, restartBrowsing: true)
            }

            guard !Task.isCancelled else {
                return
            }

            let events = await transport.events
            for await event in events {
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

        if shouldAttemptSavedPairingCodeReconnect {
            isBackgroundReconnecting = true
            startBackgroundReconnect()
        } else {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else {
                    return
                }

                let transport = await self.ensureTransport()
                await self.refreshDiscovery(using: transport, restartBrowsing: true)
            }
        }
    }

    private func startBackgroundReconnect(initialDelay: Duration = .milliseconds(250)) {
        guard shouldAttemptSavedPairingCodeReconnect else {
            isBackgroundReconnecting = false
            return
        }

        hasFailedBackgroundReconnect = false
        isBackgroundReconnecting = true
        backgroundReconnectTask?.cancel()
        backgroundReconnectTask = Task { [weak self] in
            guard let self else { return }

            let transport = await self.ensureTransport()
            await self.startBackgroundReconnect(using: transport, initialDelay: initialDelay)
        }
    }

    private func startBackgroundReconnect(
        using transport: any TransportSession,
        initialDelay: Duration
    ) async {
        guard let pairingCode = validSavedPairingCode else {
            isBackgroundReconnecting = false
            return
        }

        hasFailedBackgroundReconnect = false
        do {
            if initialDelay > .zero {
                try? await Task.sleep(for: initialDelay)
                try Task.checkCancellation()
            }

            await startDiscovery(using: transport)

            let currentState = await transport.state
            if case .connected = currentState {
                applyTransportState(currentState)
                isBackgroundReconnecting = false
                backgroundReconnectTask = nil
                return
            }

            guard let peer = try await waitForPreferredMac(using: transport, timeout: .seconds(6)) else {
                finishBackgroundReconnectFailure(localized("ios.error.noNearbyMac"))
                hasCompletedInitialDiscovery = true
                backgroundReconnectTask = nil
                return
            }

            discovery.connectionState = .reconnecting(peer)

            try await Self.performTransportOperation {
                try await transport.connect(to: peer, pairingCode: pairingCode)
            }

            let connectionState = try await waitForConnectionResult(using: transport, timeout: .seconds(12))
            discovery.connectionState = connectionState
            if case let .connected(peer) = connectionState {
                hasFailedBackgroundReconnect = false
                selectMac(peer)
                connectionErrorMessage = nil
                isBackgroundReconnecting = false
            } else {
                finishBackgroundReconnectFailure(connectionFailureMessage(for: connectionState))
            }
            backgroundReconnectTask = nil
        } catch is CancellationError {
            backgroundReconnectTask = nil
        } catch {
            finishBackgroundReconnectFailure(error.localizedDescription)
            hasCompletedInitialDiscovery = true
            backgroundReconnectTask = nil
        }
    }

    private func startDiscovery(using transport: any TransportSession) async {
        let snapshot = await Task.detached(priority: .userInitiated) {
            await transport.startDiscovery()
            return (state: await transport.state, peers: await transport.discoveredPeers)
        }.value

        applyTransportState(snapshot.state)
        discovery.availableMacs = snapshot.peers
        hasCompletedInitialDiscovery = true
    }

    private func waitForPreferredMac(
        using transport: any TransportSession,
        timeout: Duration
    ) async throws -> TransportPeer? {
        if let peer = preferredDiscoveredMac {
            return peer
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            try Task.checkCancellation()

            if let peer = preferredDiscoveredMac {
                return peer
            }

            discovery.availableMacs = await transport.discoveredPeers
            if let peer = preferredDiscoveredMac {
                return peer
            }

            try await Task.sleep(for: .milliseconds(250))
        }

        discovery.availableMacs = await transport.discoveredPeers
        return preferredDiscoveredMac
    }

    private func waitForConnectionResult(
        using transport: any TransportSession,
        timeout: Duration
    ) async throws -> TransportConnectionState {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            try Task.checkCancellation()

            let state = await transport.state
            switch state {
            case .connected, .disconnected, .failed:
                return state
            default:
                try await Task.sleep(for: .milliseconds(250))
            }
        }

        return .failed(localized("ios.error.connectionTimeout"))
    }

    private func connectionFailureMessage(for state: TransportConnectionState) -> String {
        switch state {
        case let .failed(message):
            return message
        case let .disconnected(reason):
            return reason ?? localized("ios.error.disconnectedEnterPairingCode")
        default:
            return localized("ios.error.connectionTimeout")
        }
    }

    private func finishBackgroundReconnectFailure(_ message: String) {
        hasFailedBackgroundReconnect = true
        connectionErrorMessage = message
        discovery.connectionState = .failed(message)
        settings.pairingCodeInput = ""
        isBackgroundReconnecting = false
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
        // 如果正在后台重连，不触发连接
        guard !isBackgroundReconnecting else {
            return
        }

        guard normalizedPairingCodeInput.count == 4 else {
            if manuallyTriggered {
                connectionErrorMessage = localized("ios.error.enterFourDigitPairingCode")
            }
            return
        }

        guard canStartConnection else {
            return
        }

        guard let peer = preferredDiscoveredMac else {
            connectionErrorMessage = manuallyTriggered ? localized("ios.settings.mac.searching") : nil
            return
        }

        connect(to: peer)
    }

    func connect(to peer: TransportPeer) {
        let pairingCode = normalizedPairingCodeInput
        guard pairingCode.count == 4 else {
            connectionErrorMessage = localized("ios.error.enterFourDigitPairingCode")
            discovery.connectionState = .failed(localized("ios.error.enterFourDigitCodeShort"))
            return
        }

        allowsAutomaticReconnect = true
        hasFailedBackgroundReconnect = false
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
                selectMac(peer)
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
            connectionErrorMessage = localized("ios.error.enterFourDigitPairingCode")
            discovery.connectionState = .failed(localized("ios.error.enterFourDigitCodeShort"))
            return
        }

        allowsAutomaticReconnect = true
        hasFailedBackgroundReconnect = false
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
        backgroundReconnectTask?.cancel()
        backgroundReconnectTask = nil
        isBackgroundReconnecting = false
        connectionErrorMessage = nil
        pairingCode = nil
        versionMismatchNotice = nil
        clearPeerHandshakeState()
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

    func dismissVersionMismatchNotice() {
        dismissedVersionMismatchNoticeID = versionMismatchNotice?.id
        versionMismatchNotice = nil
    }

    private func handleTransportEvent(_ event: TransportEvent) async {
        switch event.kind {
        case let .stateChanged(state):
            applyTransportState(state)
            if case let .connected(peer) = state {
                hasFailedBackgroundReconnect = false
                isBackgroundReconnecting = false
                selectMac(peer)
                connectionErrorMessage = nil
                await sendPairingHandshake()
            } else if case .disconnected = state {
                clearPeerHandshakeState()
                guard !isBackgroundReconnecting else {
                    return
                }

                if allowsAutomaticReconnect, shouldAttemptSavedPairingCodeReconnect {
                    startBackgroundReconnect(initialDelay: .milliseconds(500))
                } else if !hasFailedBackgroundReconnect {
                    scheduleReconnectIfNeeded()
                }
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
        case let .hello(payload):
            pairedMacAppVersion = payload.appVersionDisplayText
            updateVersionMismatchNotice(remoteAppVersion: payload.appVersion)
            negotiatedProtocolVersion = payload.highestCompatibleProtocolVersion
            peerProtocolIsCompatible = payload.isProtocolCompatible
            if let remoteLanguage = RemoteDockLanguage.resolved(from: payload.languageCode) {
                updateRemoteLanguage(remoteLanguage)
            }
        case let .pairApprove(payload):
            hasFailedBackgroundReconnect = false
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
            requestMissingClipboardIcons(for: payload.items)
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
            appVersion: Bundle.main.remoteDockAppVersion,
            buildNumber: Bundle.main.remoteDockBuildNumber,
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
            requestMissingClipboardIcons(for: [item])
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

    private func requestMissingClipboardIcons(for items: [ClipboardItem]) {
        requestMissingIcons(for: items.compactMap { clipboardIconHash(for: $0) })
    }

    private func requestMissingIcons(for hashes: [String]) {
        let knownHashes = Set(dock.iconImagesByHash.keys)
            .union(runningApps.iconImagesByHash.keys)
            .union(clipboard.sourceAppIconImagesByHash.keys)
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

        var updatedClipboard = clipboard
        updatedClipboard.sourceAppIconImagesByHash[payload.asset.hash] = image
        clipboard = updatedClipboard
    }

    private func clipboardIconHash(for item: ClipboardItem) -> String? {
        guard let hash = item.sourceAppBundleId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hash.isEmpty else {
            return nil
        }

        return hash
    }

    private var normalizedPairingCodeInput: String {
        String(settings.pairingCodeInput.filter(\.isNumber).prefix(4))
    }

    private var validSavedPairingCode: String? {
        Self.validPairingCode(from: settings.savedPairingCode)
    }

    private var shouldAttemptSavedPairingCodeReconnect: Bool {
        validSavedPairingCode != nil && !hasFailedBackgroundReconnect
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

    private func localized(_ key: String) -> String {
        settings.remoteLanguage.localizedString(key)
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

    private func clearPeerHandshakeState() {
        pairedMacAppVersion = nil
        versionMismatchNotice = nil
        dismissedVersionMismatchNoticeID = nil
        negotiatedProtocolVersion = nil
        peerProtocolIsCompatible = true
    }

    private func updateVersionMismatchNotice(remoteAppVersion: String?) {
        guard let mismatch = RemoteDockAppVersionComparator.mismatch(
            local: Bundle.main.remoteDockAppVersion,
            remote: remoteAppVersion
        ),
              let phoneVersion = Bundle.main.remoteDockAppVersionDisplayText,
              let macVersion = pairedMacAppVersion else {
            versionMismatchNotice = nil
            return
        }

        let notice = RemoteDockVersionMismatchNotice(
            mismatch: mismatch,
            phoneVersion: phoneVersion,
            macVersion: macVersion
        )
        guard dismissedVersionMismatchNoticeID != notice.id else {
            return
        }

        versionMismatchNotice = notice
    }

    private func updateRemoteLanguage(_ language: RemoteDockLanguage) {
        guard settings.remoteLanguage != language else {
            return
        }

        settings.remoteLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.remoteLanguageDefaultsKey)
    }

    private func selectMac(_ peer: TransportPeer) {
        settings.selectedMacId = peer.id
        UserDefaults.standard.set(peer.id, forKey: Self.selectedMacIdDefaultsKey)
    }

    private func scheduleReconnectIfNeeded() {
        // 如果正在后台重连，不触发自动重连
        guard !isBackgroundReconnecting else {
            return
        }
        guard !hasFailedBackgroundReconnect else {
            return
        }

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
                // 再次检查是否在后台重连，因为在异步任务期间状态可能发生变化
                guard let self, !self.isBackgroundReconnecting else {
                    return
                }
                self.reconnectTask = nil
                self.reconnect()
            }
        }
    }

    private static let savedPairingCodeDefaultsKey = "remoteDock.iOS.savedPairingCode"
    private static let selectedMacIdDefaultsKey = "remoteDock.iOS.selectedMacId"
    private static let remoteLanguageDefaultsKey = "remoteDock.iOS.remoteLanguage"
    private static let iconGridCountDefaultsKey = "remoteDock.iOS.iconGridCount"
    private static let clipboardFontSizeDefaultsKey = "remoteDock.iOS.clipboardFontSize"
    private static let movePastedClipboardItemToTopDefaultsKey = "remoteDock.iOS.movePastedClipboardItemToTop"
    private static let moveActivatedRunningAppToTopDefaultsKey = "remoteDock.iOS.moveActivatedRunningAppToTop"

    private static func savePairingCode(_ pairingCode: String) {
        UserDefaults.standard.set(pairingCode, forKey: savedPairingCodeDefaultsKey)
    }

    private static func validPairingCode(from value: String?) -> String? {
        guard let value else {
            return nil
        }

        let pairingCode = String(value.filter(\.isNumber).prefix(4))
        return pairingCode.count == 4 ? pairingCode : nil
    }

    private static func loadIconGridCount() -> PhoneIconGridCount {
        let rawValue = UserDefaults.standard.integer(forKey: iconGridCountDefaultsKey)
        return PhoneIconGridCount(rawValue: rawValue) ?? .four
    }

    private static func loadRemoteLanguage() -> RemoteDockLanguage {
        RemoteDockLanguage.resolved(
            from: UserDefaults.standard.string(forKey: remoteLanguageDefaultsKey)
        ) ?? .english
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

private extension Bundle {
    var remoteDockAppVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    var remoteDockBuildNumber: String? {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    var remoteDockAppVersionDisplayText: String? {
        guard let appVersion = remoteDockAppVersion else {
            return nil
        }

        if let buildNumber = remoteDockBuildNumber, buildNumber != appVersion {
            return "\(appVersion) (\(buildNumber))"
        }

        return appVersion
    }
}

private extension HelloPayload {
    var appVersionDisplayText: String? {
        guard let appVersion else {
            return nil
        }

        if let buildNumber, buildNumber != appVersion {
            return "\(appVersion) (\(buildNumber))"
        }

        return appVersion
    }
}
