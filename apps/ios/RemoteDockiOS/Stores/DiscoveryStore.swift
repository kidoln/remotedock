import Foundation
import RemoteDockTransport

struct DiscoveryStore: Equatable {
    var connectionState: TransportConnectionState = .idle
    var availableMacs: [TransportPeer] = []
}
