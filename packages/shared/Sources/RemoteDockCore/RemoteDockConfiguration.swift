import Foundation

public struct RemoteDockConfiguration: Equatable, Sendable {
    public var maxClipboardItems: Int
    public var maxClipboardTextBytes: Int
    public var clipboardPollingInterval: Duration
    public var excludedClipboardSourceBundleIdentifiers: Set<String>

    public init(
        maxClipboardItems: Int = 100,
        maxClipboardTextBytes: Int = 16 * 1024,
        clipboardPollingInterval: Duration = .milliseconds(500),
        excludedClipboardSourceBundleIdentifiers: Set<String> = []
    ) {
        self.maxClipboardItems = maxClipboardItems
        self.maxClipboardTextBytes = maxClipboardTextBytes
        self.clipboardPollingInterval = clipboardPollingInterval
        self.excludedClipboardSourceBundleIdentifiers = excludedClipboardSourceBundleIdentifiers
    }
}
