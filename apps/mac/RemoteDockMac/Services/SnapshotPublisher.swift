import Foundation
import RemoteDockProtocol
import RemoteDockTransport

struct SnapshotPublisher {
    func publishCommandResult(
        _ result: CommandResultPayload,
        through peerSessionManager: PeerSessionManager
    ) async {
        try? await peerSessionManager.send(.commandResult(result))
    }
}
