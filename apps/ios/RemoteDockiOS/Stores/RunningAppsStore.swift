import Foundation
import RemoteDockCore

struct RunningAppsStore: Equatable {
    var apps: [RunningApp] = []
    var lastActivatedAppId: String?
}
