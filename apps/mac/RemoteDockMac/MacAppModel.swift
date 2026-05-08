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
        case .discoveredPeersChanged:
            break
        }
    }

    private func handleMessage(_ message: RemoteDockMessage) async {
        switch message {
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
