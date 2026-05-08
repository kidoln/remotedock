import Foundation
import RemoteDockCore
import UIKit

struct DockStore: Equatable {
    var apps: [PinnedApp] = []
    var lastActivatedAppId: String?
    var iconImagesByHash: [String: UIImage] = [:]

    static func == (lhs: DockStore, rhs: DockStore) -> Bool {
        lhs.apps == rhs.apps &&
            lhs.lastActivatedAppId == rhs.lastActivatedAppId &&
            Set(lhs.iconImagesByHash.keys) == Set(rhs.iconImagesByHash.keys)
    }
}
