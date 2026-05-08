import Foundation
import RemoteDockCore
import UIKit

struct RunningAppsStore: Equatable {
    var apps: [RunningApp] = []
    var lastActivatedAppId: String?
    var iconImagesByHash: [String: UIImage] = [:]

    var activeAppId: String? {
        apps.first(where: \.isActive)?.id ?? lastActivatedAppId
    }

    static func == (lhs: RunningAppsStore, rhs: RunningAppsStore) -> Bool {
        lhs.apps == rhs.apps &&
            lhs.lastActivatedAppId == rhs.lastActivatedAppId &&
            Set(lhs.iconImagesByHash.keys) == Set(rhs.iconImagesByHash.keys)
    }
}
