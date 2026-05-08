import Foundation
import RemoteDockCore

enum MockBootstrap {
    static let pinnedApps: [PinnedApp] = [
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
            id: "com.apple.dt.Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            appPath: "/Applications/Xcode.app",
            sortOrder: 2
        ),
        PinnedApp(
            id: "com.apple.Terminal",
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            sortOrder: 3
        )
    ]

    static let runningApps: [RunningApp] = [
        RunningApp(
            id: "com.apple.Safari",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            pid: 431,
            isActive: true,
            launchedAt: Date(timeIntervalSinceNow: -4200)
        ),
        RunningApp(
            id: "com.apple.dt.Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            pid: 611,
            isActive: false,
            launchedAt: Date(timeIntervalSinceNow: -2200)
        ),
        RunningApp(
            id: "com.apple.finder",
            bundleIdentifier: "com.apple.finder",
            displayName: "Finder",
            pid: 188,
            isActive: false,
            launchedAt: Date(timeIntervalSinceNow: -9800)
        )
    ]

    static let clipboardItems: [ClipboardItem] = [
        makeClipboardItem("Release notes: finish Phase 0 scaffold and run SwiftPM tests.", secondsAgo: 140),
        makeClipboardItem("xcodebuild -workspace RemoteDock.xcworkspace -scheme RemoteDockMac build", secondsAgo: 500),
        makeClipboardItem("MVP: discovery, pinned apps, activate app command.", secondsAgo: 900)
    ]

    private static func makeClipboardItem(_ text: String, secondsAgo: TimeInterval) -> ClipboardItem {
        let hash = ClipboardHistoryReducer.contentHash(for: text)
        return ClipboardItem(
            id: hash,
            plainText: text,
            sourceAppBundleId: "mock",
            createdAt: Date(timeIntervalSinceNow: -secondsAgo),
            contentHash: hash
        )
    }
}
