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
            return Self.defaultPinnedApps.map(normalizedIconHash)
        }
        return apps
            .map(normalizedIconHash)
            .sorted { $0.sortOrder < $1.sortOrder }
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
        let normalizedApps = apps
            .map(normalizedIconHash)
            .sorted(by: { $0.sortOrder < $1.sortOrder })

        guard let data = try? JSONEncoder().encode(normalizedApps) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private func normalizedIconHash(_ app: PinnedApp) -> PinnedApp {
        guard app.iconAssetHash?.isEmpty != false else {
            return app
        }

        var normalizedApp = app
        normalizedApp.iconAssetHash = app.bundleIdentifier
        return normalizedApp
    }

    static let defaultPinnedApps: [PinnedApp] = [
        PinnedApp(
            id: "com.apple.finder",
            bundleIdentifier: "com.apple.finder",
            displayName: "Finder",
            appPath: "/System/Library/CoreServices/Finder.app",
            iconAssetHash: "com.apple.finder",
            sortOrder: 0
        ),
        PinnedApp(
            id: "com.apple.Safari",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appPath: "/Applications/Safari.app",
            iconAssetHash: "com.apple.Safari",
            sortOrder: 1
        ),
        PinnedApp(
            id: "com.apple.Terminal",
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            iconAssetHash: "com.apple.Terminal",
            sortOrder: 2
        )
    ]
}
