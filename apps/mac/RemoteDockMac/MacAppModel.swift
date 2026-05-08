import Foundation
import RemoteDockCore
import RemoteDockProtocol
import RemoteDockTransport
import SwiftUI

@MainActor
final class MacAppModel: ObservableObject {
    @Published private(set) var connectionState: TransportConnectionState = .idle
    @Published private(set) var pinnedApps: [PinnedApp] = []
    @Published private(set) var runningApps: [RunningApp] = []
    @Published private(set) var clipboardItems: [ClipboardItem] = []
    @Published private(set) var permissionStatus = PermissionCenter.Status()
    @Published private(set) var pairedDeviceName: String?
    @Published var clipboardSyncEnabled = true

    private let permissionCenter = PermissionCenter()
    private let peerSessionManager = PeerSessionManager()
    private let pinnedAppsService = PinnedAppsService()
    private let runningAppsService = RunningAppsService()
    private let clipboardHistoryService = ClipboardHistoryService()
    private let commandExecutor = MacCommandExecutor()
    private let snapshotPublisher = SnapshotPublisher()

    private var refreshTask: Task<Void, Never>?

    var menuBarSystemImage: String {
        switch connectionState {
        case .connected:
            "dot.radiowaves.left.and.right"
        case .failed:
            "exclamationmark.triangle"
        default:
            "dock.rectangle"
        }
    }

    init() {
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
                    self.refresh()
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
            for await items in clipboardHistoryService.startMonitoring() {
                await MainActor.run {
                    if self.clipboardSyncEnabled {
                        self.clipboardItems = items
                    }
                }
            }
        }
    }

    func refresh() {
        permissionStatus = permissionCenter.currentStatus()
        connectionState = peerSessionManager.currentState
        pinnedApps = pinnedAppsService.loadPinnedApps()
        runningApps = runningAppsService.currentRunningApps()
        clipboardItems = clipboardHistoryService.currentItems
    }

    func openAccessibilitySettings() {
        permissionCenter.openAccessibilitySettings()
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
    }

    func addFrontmostApplicationToPinnedApps() {
        guard let activeApp = runningAppsService.frontmostApplicationAsPinnedApp(
            sortOrder: pinnedApps.count
        ) else {
            return
        }
        pinnedAppsService.upsertPinnedApp(activeApp)
        refresh()
    }

    func clearClipboardHistory() {
        clipboardHistoryService.clear()
        refresh()
    }

    private func handleTransportEvent(_ event: TransportEvent) async {
        switch event.kind {
        case let .stateChanged(state):
            await MainActor.run {
                self.connectionState = state
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
            }
        case let .pairRequest(payload):
            await approvePairing(payload)
        case let .activateAppCommand(payload):
            let result = await commandExecutor.handleActivateAppCommand(payload)
            await snapshotPublisher.publishCommandResult(result, through: peerSessionManager)
        case let .pasteClipboardItemCommand(payload):
            let result = await commandExecutor.handlePasteClipboardItemCommand(payload)
            await snapshotPublisher.publishCommandResult(result, through: peerSessionManager)
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
            pairingCode: Self.pairingCode(for: payload.deviceId)
        )
        try? await peerSessionManager.send(.pairApprove(approval))

        let hello = HelloPayload(
            deviceId: Host.current().localizedName ?? "remote-dock-mac",
            deviceName: Host.current().localizedName ?? "Remote Dock Mac",
            platform: .macOS,
            capabilities: [.appActivation, .runningApps, .clipboardHistory, .clipboardPaste, .iconSync]
        )
        try? await peerSessionManager.send(.hello(hello))
        await publishSnapshots()
    }

    private func publishSnapshots() async {
        await snapshotPublisher.publishAppsSnapshot(pinnedApps, through: peerSessionManager)
        await snapshotPublisher.publishRunningAppsSnapshot(runningApps, through: peerSessionManager)
        if clipboardSyncEnabled {
            await snapshotPublisher.publishClipboardSnapshot(clipboardItems, through: peerSessionManager)
        }
    }

    private static func pairingCode(for deviceId: String) -> String {
        let scalarSum = deviceId.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return String(format: "%06d", scalarSum % 1_000_000)
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
