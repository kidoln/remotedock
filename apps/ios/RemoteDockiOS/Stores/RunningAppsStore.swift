import Foundation
import RemoteDockCore
import UIKit

struct RunningAppsStore: Equatable {
    var apps: [RunningApp] = []
    var lastActivatedAppId: String?
    var iconImagesByHash: [String: UIImage] = [:]

    static func == (lhs: RunningAppsStore, rhs: RunningAppsStore) -> Bool {
        lhs.apps == rhs.apps &&
            lhs.lastActivatedAppId == rhs.lastActivatedAppId &&
            Set(lhs.iconImagesByHash.keys) == Set(rhs.iconImagesByHash.keys)
    }
}
