import Foundation
import RemoteDockCore
import RemoteDockProtocol
import RemoteDockTransport

struct SnapshotPublisher {
    func publishAppsSnapshot(
        _ apps: [PinnedApp],
        through peerSessionManager: PeerSessionManager
    ) async {
        try? await peerSessionManager.send(.appsSnapshot(AppsSnapshotPayload(apps: apps)))
    }

    func publishRunningAppsSnapshot(
        _ apps: [RunningApp],
        through peerSessionManager: PeerSessionManager
    ) async {
        try? await peerSessionManager.send(.runningAppsSnapshot(RunningAppsSnapshotPayload(apps: apps)))
    }

    func publishClipboardSnapshot(
        _ items: [ClipboardItem],
        through peerSessionManager: PeerSessionManager
    ) async {
        try? await peerSessionManager.send(.clipboardSnapshot(ClipboardSnapshotPayload(items: items)))
    }

    func publishClipboardInserted(
        _ item: ClipboardItem,
        through peerSessionManager: PeerSessionManager
    ) async {
        let payload = ClipboardDeltaPayload(operation: .inserted, item: item)
        try? await peerSessionManager.send(.clipboardDelta(payload))
    }

    func publishClipboardCleared(through peerSessionManager: PeerSessionManager) async {
        try? await peerSessionManager.send(.clipboardDelta(ClipboardDeltaPayload(operation: .cleared)))
    }

    func publishCommandResult(
        _ result: CommandResultPayload,
        through peerSessionManager: PeerSessionManager
    ) async {
        try? await peerSessionManager.send(.commandResult(result))
    }
}
