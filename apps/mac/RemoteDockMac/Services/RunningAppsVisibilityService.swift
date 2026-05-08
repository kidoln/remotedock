import Foundation

final class RunningAppsVisibilityService {
    private let storageKey = "remoteDock.hiddenRunningAppBundleIds.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadHiddenBundleIds() -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    func setHidden(_ isHidden: Bool, bundleIdentifier: String) {
        var bundleIds = loadHiddenBundleIds()

        if isHidden {
            bundleIds.insert(bundleIdentifier)
        } else {
            bundleIds.remove(bundleIdentifier)
        }

        defaults.set(Array(bundleIds).sorted(), forKey: storageKey)
    }

    func toggle(bundleIdentifier: String) -> Bool {
        let isHidden = !loadHiddenBundleIds().contains(bundleIdentifier)
        setHidden(isHidden, bundleIdentifier: bundleIdentifier)
        return isHidden
    }
}
