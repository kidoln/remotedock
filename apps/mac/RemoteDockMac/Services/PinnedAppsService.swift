import Foundation
import RemoteDockCore

final class PinnedAppsService {
    private let storageKey = "remoteDock.pinnedApps.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPinnedApps() -> [PinnedApp] {
        guard let data = defaults.data(forKey: storageKey),
              let apps = try? JSONDecoder().decode([PinnedApp].self, from: data) else {
            return Self.defaultPinnedApps
        }
        return apps.sorted { $0.sortOrder < $1.sortOrder }
    }

    func upsertPinnedApp(_ app: PinnedApp) {
        var apps = loadPinnedApps().filter { $0.id != app.id }
        apps.append(app)
        save(apps)
    }

    func removePinnedApp(id: String) {
        save(loadPinnedApps().filter { $0.id != id })
    }

    private func save(_ apps: [PinnedApp]) {
        guard let data = try? JSONEncoder().encode(apps.sorted(by: { $0.sortOrder < $1.sortOrder })) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    static let defaultPinnedApps: [PinnedApp] = [
        PinnedApp(
            id: "com.apple.finder",
            bundleIdentifier: "com.apple.finder",
            displayName: "Finder",
            appPath: "/System/Library/CoreServices/Finder.app",
            sortOrder: 0
        ),
        PinnedApp(
            id: "com.apple.Safari",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appPath: "/Applications/Safari.app",
            sortOrder: 1
        ),
        PinnedApp(
            id: "com.apple.Terminal",
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            sortOrder: 2
        )
    ]
}
