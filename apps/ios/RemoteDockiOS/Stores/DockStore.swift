import Foundation
import RemoteDockCore

struct DockStore: Equatable {
    var apps: [PinnedApp] = []
    var lastActivatedAppId: String?
}
