import AppKit
import Foundation
import RemoteDockCore

@MainActor
final class ClipboardHistoryService {
    private let pasteboard: NSPasteboard
    private let policy: ClipboardHistoryPolicy
    private var lastChangeCount: Int
    private var items: [ClipboardItem] = []

    var currentItems: [ClipboardItem] {
        items
    }

    init(
        pasteboard: NSPasteboard = .general,
        policy: ClipboardHistoryPolicy = ClipboardHistoryPolicy()
    ) {
        self.pasteboard = pasteboard
        self.policy = policy
        self.lastChangeCount = pasteboard.changeCount
    }

    func startMonitoring() -> AsyncStream<[ClipboardItem]> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    pollOnce()
                    continuation.yield(items)
                    try? await Task.sleep(for: .milliseconds(500))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func pollOnce() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let text = pasteboard.string(forType: .string),
              let item = ClipboardHistoryReducer.makeItem(
                text: text,
                sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                policy: policy
              ) else {
            return
        }

        items = ClipboardHistoryReducer.inserting(item, into: items, policy: policy)
    }

    func clear() {
        items.removeAll()
    }
}
