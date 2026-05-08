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

    func publishCommandResult(
        _ result: CommandResultPayload,
        through peerSessionManager: PeerSessionManager
    ) async {
        try? await peerSessionManager.send(.commandResult(result))
    }
}
