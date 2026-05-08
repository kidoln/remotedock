import AppKit
import Foundation
import RemoteDockCore

@MainActor
final class ClipboardHistoryService {
    private let storageKey = "remoteDock.clipboardHistory.items.v1"
    private let pasteboard: NSPasteboard
    private let defaults: UserDefaults
    private var policy: ClipboardHistoryPolicy
    private var lastChangeCount: Int
    private var items: [ClipboardItem] = []
    private var globalEventMonitors: [Any] = []
    private var localEventMonitors: [Any] = []
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var pendingCaptureTask: Task<Void, Never>?

    var currentItems: [ClipboardItem] {
        items
    }

    init(
        pasteboard: NSPasteboard = .general,
        policy: ClipboardHistoryPolicy = ClipboardHistoryPolicy(),
        defaults: UserDefaults = .standard
    ) {
        self.pasteboard = pasteboard
        self.policy = policy
        self.defaults = defaults
        self.lastChangeCount = pasteboard.changeCount
        self.items = loadPersistedItems()
    }

    func startMonitoring() -> AsyncStream<ClipboardItem> {
        AsyncStream { continuation in
            installTriggerMonitors(continuation: continuation)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.stopMonitoring()
                }
            }
        }
    }

    @discardableResult
    func captureCurrentClipboardIfChanged() -> ClipboardItem? {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return nil }
        lastChangeCount = changeCount

        guard let item = currentClipboardItem() else {
            return nil
        }

        insertAndPersist(item)
        return item
    }

    private func currentClipboardItem() -> ClipboardItem? {
        guard let text = pasteboard.string(forType: .string),
              let item = ClipboardHistoryReducer.makeItem(
                text: text,
                richRepresentations: richRepresentations(from: pasteboard),
                sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                policy: policy
              ) else {
            return nil
        }

        return item
    }

    private func insertAndPersist(_ item: ClipboardItem) {
        items = ClipboardHistoryReducer.inserting(item, into: items, policy: policy)
        saveItems()
    }

    @discardableResult
    func promote(_ item: ClipboardItem) -> ClipboardItem {
        var promotedItem = item
        promotedItem.createdAt = Date()
        items = ClipboardHistoryReducer.inserting(promotedItem, into: items, policy: policy)
        saveItems()
        return promotedItem
    }

    func updateMaxItems(_ maxItems: Int) {
        policy.maxItems = max(maxItems, 0)
        items = normalizedHistory(items)
        saveItems()
    }

    func clear() {
        items.removeAll()
        saveItems()
    }

    private func loadPersistedItems() -> [ClipboardItem] {
        guard let data = defaults.data(forKey: storageKey),
              let decodedItems = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }

        return normalizedHistory(decodedItems)
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private func normalizedHistory(_ history: [ClipboardItem]) -> [ClipboardItem] {
        var seenHashes = Set<String>()
        let sortedItems = history
            .filter { !$0.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.createdAt > $1.createdAt }

        let uniqueItems = sortedItems.filter { item in
            guard !seenHashes.contains(item.contentHash) else {
                return false
            }
            seenHashes.insert(item.contentHash)
            return true
        }

        return Array(uniqueItems.prefix(max(policy.maxItems, 0)))
    }

    private func richRepresentations(from pasteboard: NSPasteboard) -> [ClipboardRepresentation] {
        pasteboard.types?.compactMap { pasteboardType in
            guard Self.shouldPreservePasteboardType(pasteboardType),
                  let data = pasteboard.data(forType: pasteboardType) else {
                return nil
            }
            return ClipboardRepresentation(
                kind: ClipboardRepresentationKind(pasteboardTypeIdentifier: pasteboardType.rawValue),
                data: data
            )
        } ?? []
    }

    private func installTriggerMonitors(continuation: AsyncStream<ClipboardItem>.Continuation) {
        stopMonitoring()

        let scheduleCapture: @MainActor ([Duration]) -> Void = { [weak self] delays in
            self?.scheduleClipboardCapture(delays: delays, continuation: continuation)
        }

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            guard Self.isClipboardMutationShortcut(event) else { return }
            Task { @MainActor in
                scheduleCapture(Self.shortcutCaptureDelays)
            }
        }) {
            globalEventMonitors.append(monitor)
        }

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: Self.pointerUpEventMask, handler: { _ in
            Task { @MainActor in
                scheduleCapture(Self.interactionCaptureDelays)
            }
        }) {
            globalEventMonitors.append(monitor)
        }

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            guard Self.isClipboardMutationShortcut(event) else { return event }
            Task { @MainActor in
                scheduleCapture(Self.shortcutCaptureDelays)
            }
            return event
        }) {
            localEventMonitors.append(monitor)
        }

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: Self.pointerUpEventMask, handler: { event in
            Task { @MainActor in
                scheduleCapture(Self.interactionCaptureDelays)
            }
            return event
        }) {
            localEventMonitors.append(monitor)
        }

        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                scheduleCapture(Self.interactionCaptureDelays)
            }
        }
    }

    private func stopMonitoring() {
        pendingCaptureTask?.cancel()
        pendingCaptureTask = nil

        for monitor in globalEventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalEventMonitors.removeAll()

        for monitor in localEventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        localEventMonitors.removeAll()

        if let workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceNotificationObserver)
            self.workspaceNotificationObserver = nil
        }
    }

    private func scheduleClipboardCapture(
        delays: [Duration],
        continuation: AsyncStream<ClipboardItem>.Continuation
    ) {
        pendingCaptureTask?.cancel()
        pendingCaptureTask = Task { @MainActor [weak self] in
            let lastObservedChangeCount = self?.lastChangeCount
            var bestItem: ClipboardItem?

            for delay in delays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                guard self.pasteboard.changeCount != self.lastChangeCount else {
                    continue
                }

                if let item = self.currentClipboardItem(),
                   Self.shouldPrefer(item, over: bestItem) {
                    bestItem = item
                }
            }

            guard !Task.isCancelled,
                  let self,
                  let bestItem,
                  let lastObservedChangeCount,
                  self.pasteboard.changeCount != lastObservedChangeCount else {
                return
            }

            self.lastChangeCount = self.pasteboard.changeCount
            self.insertAndPersist(bestItem)
            continuation.yield(bestItem)
        }
    }

    private nonisolated static func shouldPrefer(_ item: ClipboardItem, over existingItem: ClipboardItem?) -> Bool {
        guard let existingItem else {
            return true
        }

        let richByteCount = item.richRepresentations.reduce(0) { $0 + $1.data.count }
        let existingRichByteCount = existingItem.richRepresentations.reduce(0) { $0 + $1.data.count }
        if richByteCount != existingRichByteCount {
            return richByteCount > existingRichByteCount
        }

        return item.richRepresentations.count > existingItem.richRepresentations.count
    }

    private nonisolated static let shortcutCaptureDelays: [Duration] = [
        .milliseconds(80),
        .milliseconds(220),
        .milliseconds(520),
        .milliseconds(900)
    ]

    private nonisolated static let interactionCaptureDelays: [Duration] = [
        .milliseconds(120),
        .milliseconds(300),
        .milliseconds(700)
    ]

    private nonisolated static let excludedPreservedPasteboardTypes: Set<String> = [
        NSPasteboard.PasteboardType.string.rawValue,
        NSPasteboard.PasteboardType.tabularText.rawValue,
        NSPasteboard.PasteboardType.font.rawValue,
        NSPasteboard.PasteboardType.ruler.rawValue,
        NSPasteboard.PasteboardType.color.rawValue,
        NSPasteboard.PasteboardType.sound.rawValue,
        NSPasteboard.PasteboardType.multipleTextSelection.rawValue,
        "public.utf8-plain-text",
        "public.utf16-plain-text",
        "public.text"
    ]

    private nonisolated static func shouldPreservePasteboardType(_ pasteboardType: NSPasteboard.PasteboardType) -> Bool {
        let identifier = pasteboardType.rawValue
        let lowercasedIdentifier = identifier.lowercased()

        guard !excludedPreservedPasteboardTypes.contains(identifier),
              !lowercasedIdentifier.contains("dyn."),
              !lowercasedIdentifier.contains("plain-text") else {
            return false
        }

        return lowercasedIdentifier.contains("rtf") ||
            lowercasedIdentifier.contains("html") ||
            lowercasedIdentifier.contains("webarchive") ||
            lowercasedIdentifier.contains("microsoft") ||
            lowercasedIdentifier.contains("office") ||
            lowercasedIdentifier.contains("word")
    }

    private nonisolated static let pointerUpEventMask: NSEvent.EventTypeMask = [
        .leftMouseUp,
        .rightMouseUp,
        .otherMouseUp
    ]

    private nonisolated static func isClipboardMutationShortcut(_ event: NSEvent) -> Bool {
        guard !event.isARepeat else { return false }

        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard relevantFlags.contains(.command),
              relevantFlags.subtracting([.command, .shift]).isEmpty else {
            return false
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c", "x":
            return true
        default:
            return false
        }
    }
}
