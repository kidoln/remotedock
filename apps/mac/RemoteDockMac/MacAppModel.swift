import Foundation
import RemoteDockCore
import RemoteDockProtocol
import RemoteDockTransport
import SwiftUI

private let macIdDefaultsKey = "remoteDock.mac.id"
private let macPairingCodeDefaultsKey = "remoteDock.mac.pairingCode"

@MainActor
final class MacAppModel: ObservableObject {
    @Published private(set) var connectionState: TransportConnectionState = .idle
    @Published private(set) var macId: String
    @Published private(set) var pairingCode: String
    @Published private(set) var pinnedApps: [PinnedApp] = []
    @Published private(set) var runningApps: [RunningApp] = []
    @Published private(set) var catalogApps: [CatalogApp] = []
    @Published private(set) var hiddenRunningAppBundleIds: Set<String> = []
    @Published private(set) var clipboardItems: [ClipboardItem] = []
    @Published private(set) var clipboardHistorySettings: ClipboardHistorySettings
    @Published private(set) var clipboardHistoryShortcutIsRegistered = true
    @Published private(set) var clipboardHistoryPanelErrorMessage: String?
    @Published private(set) var permissionStatus = PermissionCenter.Status()
    @Published private(set) var pairedDeviceName: String?
    @Published private(set) var pairedDeviceAppVersion: String?
    @Published private(set) var negotiatedProtocolVersion: Int?
    @Published private(set) var peerProtocolIsCompatible = true
    @Published private(set) var language: RemoteDockLanguage
    @Published var clipboardSyncEnabled = true

    var clipboardHistoryShortcutDidChange: ((ClipboardHistoryShortcut) -> Bool)?

    private let permissionCenter = PermissionCenter()
    private let peerSessionManager: PeerSessionManager
    private let pinnedAppsService = PinnedAppsService()
    private let runningAppsService = RunningAppsService()
    private let appCatalogService = AppCatalogService()
    private let runningAppsVisibilityService = RunningAppsVisibilityService()
    private let languageSettingsService = LanguageSettingsService()
    private let clipboardHistorySettingsService: ClipboardHistorySettingsService
    private let clipboardHistoryService: ClipboardHistoryService
    private let appIconAssetService = AppIconAssetService()
    private let commandExecutor = MacCommandExecutor()
    private let snapshotPublisher = SnapshotPublisher()

    private var refreshTask: Task<Void, Never>?

    init() {
        let clipboardHistorySettingsService = ClipboardHistorySettingsService()
        let clipboardHistorySettings = clipboardHistorySettingsService.load()
        self.clipboardHistorySettingsService = clipboardHistorySettingsService
        self.clipboardHistorySettings = clipboardHistorySettings
        self.clipboardHistoryService = ClipboardHistoryService(
            policy: ClipboardHistoryPolicy(maxItems: clipboardHistorySettings.maxItems)
        )
        language = languageSettingsService.load()

        let macId = Self.loadMacId()
        let pairingCode = Self.loadPairingCode()
        self.macId = macId
        self.pairingCode = pairingCode
        peerSessionManager = PeerSessionManager(macId: macId, pairingCodeValidator: { submittedCode in
            submittedCode == UserDefaults.standard.string(forKey: macPairingCodeDefaultsKey)
        })
        pinnedApps = pinnedAppsService.loadPinnedApps()
        refresh()
        start()
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await peerSessionManager.start()
            for await _ in TimerSequence(interval: .seconds(2)) {
                await peerSessionManager.refreshState()
                await MainActor.run {
                    self.refresh(publishingRunningAppsChanges: true)
                }
            }
        }

        Task { [weak self] in
            guard let self else { return }
            for await event in await peerSessionManager.events {
                await handleTransportEvent(event)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            for await item in clipboardHistoryService.startMonitoring() {
                self.clipboardItems = self.clipboardHistoryService.currentItems
                if self.clipboardSyncEnabled {
                    await self.snapshotPublisher.publishClipboardInserted(item, through: self.peerSessionManager)
                }
            }
        }
    }

    func refresh(publishingRunningAppsChanges: Bool = false) {
        let previousVisibleRunningApps = visibleRunningApps

        permissionStatus = permissionCenter.currentStatus()
        connectionState = peerSessionManager.currentState
        pinnedApps = pinnedAppsService.loadPinnedApps()
        runningApps = runningAppsService.currentRunningApps()
        hiddenRunningAppBundleIds = runningAppsVisibilityService.loadHiddenBundleIds()
        clipboardItems = clipboardHistoryService.currentItems

        if publishingRunningAppsChanges, visibleRunningApps != previousVisibleRunningApps {
            publishRunningAppsSnapshot()
        }
    }

    func refreshCatalogApps() {
        catalogApps = appCatalogService.installedApplications()
    }

    func openAccessibilitySettings() {
        permissionCenter.openAccessibilitySettings()
    }

    func regeneratePairingCode() {
        pairingCode = Self.generatePairingCode()
        Self.savePairingCode(pairingCode)
    }

    func activatePinnedApp(_ app: PinnedApp) {
        Task {
            _ = try? await commandExecutor.activateApp(
                bundleIdentifier: app.bundleIdentifier,
                appPath: app.appPath
            )
        }
    }

    func activateRunningApp(_ app: RunningApp) {
        Task {
            _ = try? await commandExecutor.activateApp(
                bundleIdentifier: app.bundleIdentifier,
                appPath: nil
            )
        }
    }

    func removePinnedApp(_ app: PinnedApp) {
        pinnedAppsService.removePinnedApp(id: app.id)
        refresh()
        publishAppsSnapshot()
    }

    func addPinnedApp(_ app: CatalogApp) {
        pinnedAppsService.upsertPinnedApp(app.pinnedApp(sortOrder: pinnedApps.count))
        refresh()
        publishAppsSnapshot()
    }

    func addFrontmostApplicationToPinnedApps() {
        guard let activeApp = runningAppsService.frontmostApplicationAsPinnedApp(
            sortOrder: pinnedApps.count
        ) else {
            return
        }
        pinnedAppsService.upsertPinnedApp(activeApp)
        refresh()
        publishAppsSnapshot()
    }

    func isRunningAppHidden(_ app: RunningApp) -> Bool {
        hiddenRunningAppBundleIds.contains(app.bundleIdentifier)
    }

    func toggleRunningAppVisibility(_ app: RunningApp) {
        _ = runningAppsVisibilityService.toggle(bundleIdentifier: app.bundleIdentifier)
        refresh()
        publishRunningAppsSnapshot()
    }

    func clearClipboardHistory() {
        clipboardHistoryService.clear()
        refresh()
        if clipboardSyncEnabled {
            Task {
                await snapshotPublisher.publishClipboardCleared(through: peerSessionManager)
            }
        }
    }

    func updateClipboardHistoryMaxItems(_ maxItems: Int) {
        let clampedMaxItems = min(max(maxItems, 1), ClipboardHistorySettings.maxAllowedItems)
        clipboardHistorySettings.maxItems = clampedMaxItems
        clipboardHistorySettingsService.saveMaxItems(clampedMaxItems)
        clipboardHistoryService.updateMaxItems(clampedMaxItems)
        refresh()
        if clipboardSyncEnabled {
            Task {
                await snapshotPublisher.publishClipboardSnapshot(clipboardItems, through: peerSessionManager)
            }
        }
    }

    func updateClipboardHistoryShortcut(_ shortcut: ClipboardHistoryShortcut) {
        clipboardHistorySettings.shortcut = shortcut
        clipboardHistorySettingsService.saveShortcut(shortcut)
        clipboardHistoryShortcutIsRegistered = clipboardHistoryShortcutDidChange?(shortcut) ?? false
        clipboardHistoryPanelErrorMessage = clipboardHistoryShortcutIsRegistered
            ? nil
            : language.localizedString("mac.error.shortcutRegistrationFailed")
    }

    func updateClipboardHistoryShortcutRegistration(isRegistered: Bool) {
        clipboardHistoryShortcutIsRegistered = isRegistered
        if !isRegistered {
            clipboardHistoryPanelErrorMessage = language.localizedString("mac.error.shortcutRegistrationFailed")
        }
    }

    func reportClipboardHistoryPanelError(_ message: String) {
        clipboardHistoryPanelErrorMessage = message
    }

    func clearClipboardHistoryPanelError() {
        clipboardHistoryPanelErrorMessage = nil
    }

    func updateLanguage(_ language: RemoteDockLanguage) {
        guard self.language != language else {
            return
        }

        self.language = language
        languageSettingsService.save(language)
        Task {
            await publishHello()
        }
    }

    @discardableResult
    func promoteClipboardHistoryItem(_ item: ClipboardItem) -> ClipboardItem {
        let promotedItem = clipboardHistoryService.promote(item)
        refresh()
        if clipboardSyncEnabled {
            Task {
                await snapshotPublisher.publishClipboardSnapshot(clipboardItems, through: peerSessionManager)
            }
        }
        return promotedItem
    }

    private func handleTransportEvent(_ event: TransportEvent) async {
        switch event.kind {
        case let .stateChanged(state):
            await MainActor.run {
                self.connectionState = state
                if case .disconnected = state {
                    self.clearPeerHandshakeState()
                }
            }
        case let .messageReceived(message):
            await handleMessage(message)
        case let .discoveredPeersChanged(peers):
            await MainActor.run {
                self.pairedDeviceName = peers.first?.displayName
            }
        }
    }

    private func handleMessage(_ message: RemoteDockMessage) async {
        switch message {
        case let .hello(payload):
            await MainActor.run {
                self.pairedDeviceName = payload.deviceName
                self.pairedDeviceAppVersion = payload.appVersionDisplayText
                self.negotiatedProtocolVersion = payload.highestCompatibleProtocolVersion
                self.peerProtocolIsCompatible = payload.isProtocolCompatible
            }
        case let .pairRequest(payload):
            await approvePairing(payload)
        case let .activateAppCommand(payload):
            NSApplication.shared.activate(ignoringOtherApps: true)
            try? await Task.sleep(nanoseconds: 50_000_000)
            let result = await commandExecutor.handleActivateAppCommand(payload)
            await snapshotPublisher.publishCommandResult(result, through: peerSessionManager)
        case let .pasteClipboardItemCommand(payload):
            let result = await commandExecutor.handlePasteClipboardItemCommand(payload)
            await snapshotPublisher.publishCommandResult(result, through: peerSessionManager)
        case let .iconRequest(payload):
            await publishIconPayloads(for: payload.hashes)
        default:
            break
        }
    }

    private func approvePairing(_ payload: PairRequestPayload) async {
        await MainActor.run {
            self.pairedDeviceName = payload.deviceName
        }

        let approval = PairApprovePayload(
            deviceId: payload.deviceId,
            approvedAt: Date(),
            pairingCode: pairingCode
        )
        try? await peerSessionManager.send(.pairApprove(approval))

        let hello = HelloPayload(
            deviceId: macId,
            deviceName: Host.current().localizedName ?? "Remote Dock Mac",
            platform: .macOS,
            appVersion: Bundle.main.remoteDockAppVersion,
            buildNumber: Bundle.main.remoteDockBuildNumber,
            languageCode: language.rawValue,
            capabilities: [.appActivation, .runningApps, .clipboardHistory, .clipboardPaste, .iconSync]
        )
        try? await peerSessionManager.send(.hello(hello))
        await publishSnapshots()
    }

    private func publishHello() async {
        let hello = HelloPayload(
            deviceId: macId,
            deviceName: Host.current().localizedName ?? "Remote Dock Mac",
            platform: .macOS,
            appVersion: Bundle.main.remoteDockAppVersion,
            buildNumber: Bundle.main.remoteDockBuildNumber,
            languageCode: language.rawValue,
            capabilities: [.appActivation, .runningApps, .clipboardHistory, .clipboardPaste, .iconSync]
        )
        try? await peerSessionManager.send(.hello(hello))
    }

    private func publishSnapshots() async {
        await snapshotPublisher.publishAppsSnapshot(pinnedApps, through: peerSessionManager)
        await snapshotPublisher.publishRunningAppsSnapshot(visibleRunningApps, through: peerSessionManager)
        await publishIconManifestAndPayloads()
        if clipboardSyncEnabled {
            await snapshotPublisher.publishClipboardSnapshot(clipboardItems, through: peerSessionManager)
        }
    }

    private var visibleRunningApps: [RunningApp] {
        runningApps.filter { !hiddenRunningAppBundleIds.contains($0.bundleIdentifier) }
    }

    private func publishAppsSnapshot() {
        Task {
            await snapshotPublisher.publishAppsSnapshot(pinnedApps, through: peerSessionManager)
            await publishIconManifestAndPayloads()
        }
    }

    private func publishRunningAppsSnapshot() {
        Task {
            await snapshotPublisher.publishRunningAppsSnapshot(visibleRunningApps, through: peerSessionManager)
            await publishIconManifestAndPayloads()
        }
    }

    private func publishIconManifestAndPayloads() async {
        let manifest = appIconAssetService.manifest(
            for: pinnedApps,
            runningApps: visibleRunningApps
        )
        await snapshotPublisher.publishIconManifest(manifest, through: peerSessionManager)
        await publishIconPayloads(for: manifest.assets.map(\.hash))
    }

    private func publishIconPayloads(for hashes: [String]) async {
        let payloads = appIconAssetService.payloads(
            for: hashes,
            pinnedApps: pinnedApps,
            runningApps: visibleRunningApps,
            clipboardItems: clipboardSyncEnabled ? clipboardItems : []
        )
        await snapshotPublisher.publishIconPayloads(payloads, through: peerSessionManager)
    }

    private func clearPeerHandshakeState() {
        pairedDeviceAppVersion = nil
        negotiatedProtocolVersion = nil
        peerProtocolIsCompatible = true
    }

    private static func loadMacId() -> String {
        if let storedMacId = UserDefaults.standard.string(forKey: macIdDefaultsKey), !storedMacId.isEmpty {
            return storedMacId
        }

        let macId = UUID().uuidString
        UserDefaults.standard.set(macId, forKey: macIdDefaultsKey)
        return macId
    }

    private static func loadPairingCode() -> String {
        if let storedPairingCode = UserDefaults.standard.string(forKey: macPairingCodeDefaultsKey),
           storedPairingCode.count == 4,
           storedPairingCode.allSatisfy(\.isNumber) {
            return storedPairingCode
        }

        let pairingCode = generatePairingCode()
        savePairingCode(pairingCode)
        return pairingCode
    }

    private static func savePairingCode(_ pairingCode: String) {
        UserDefaults.standard.set(pairingCode, forKey: macPairingCodeDefaultsKey)
    }

    private static func generatePairingCode() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }
}

private extension Bundle {
    var remoteDockAppVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    var remoteDockBuildNumber: String? {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String
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

private struct TimerSequence: AsyncSequence {
    typealias Element = Void

    let interval: Duration

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(interval: interval)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: Duration

        mutating func next() async -> Void? {
            do {
                try await Task.sleep(for: interval)
                return ()
            } catch {
                return nil
            }
        }
    }
}
