import AppKit
import Foundation
import RemoteDockCore

final class RunningAppsService {
    func currentRunningApps() -> [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular &&
                    app.bundleIdentifier?.isEmpty == false &&
                    app.localizedName?.isEmpty == false
            }
            .map { app in
                RunningApp(
                    id: app.bundleIdentifier ?? "\(app.processIdentifier)",
                    bundleIdentifier: app.bundleIdentifier ?? "",
                    displayName: app.localizedName ?? "Unknown",
                    pid: app.processIdentifier,
                    isActive: app.isActive,
                    launchedAt: app.launchDate,
                    iconAssetHash: app.bundleIdentifier
                )
            }
            .sorted {
                if $0.isActive != $1.isActive {
                    return $0.isActive && !$1.isActive
                }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    func frontmostApplicationAsPinnedApp(sortOrder: Int) -> PinnedApp? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier,
              let displayName = app.localizedName,
              let bundleURL = app.bundleURL else {
            return nil
        }

        return PinnedApp(
            id: bundleIdentifier,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            appPath: bundleURL.path,
            iconAssetHash: bundleIdentifier,
            sortOrder: sortOrder
        )
    }
}
