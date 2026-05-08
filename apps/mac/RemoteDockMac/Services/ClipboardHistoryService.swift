import AppKit
import Foundation
import RemoteDockCore

@MainActor
final class ClipboardHistoryService {
    private let pasteboard: NSPasteboard
    private let policy: ClipboardHistoryPolicy
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
        policy: ClipboardHistoryPolicy = ClipboardHistoryPolicy()
    ) {
        self.pasteboard = pasteboard
        self.policy = policy
        self.lastChangeCount = pasteboard.changeCount
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

        guard let text = pasteboard.string(forType: .string),
              let item = ClipboardHistoryReducer.makeItem(
                text: text,
                sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                policy: policy
              ) else {
            return nil
        }

        items = ClipboardHistoryReducer.inserting(item, into: items, policy: policy)
        return item
    }

    func clear() {
        items.removeAll()
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
            for delay in delays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }

                if let item = captureCurrentClipboardIfChanged() {
                    continuation.yield(item)
                    return
                }
            }
        }
    }

    private nonisolated static let shortcutCaptureDelays: [Duration] = [
        .milliseconds(50),
        .milliseconds(150),
        .milliseconds(300)
    ]

    private nonisolated static let interactionCaptureDelays: [Duration] = [
        .milliseconds(120),
        .milliseconds(300),
        .milliseconds(700)
    ]

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
