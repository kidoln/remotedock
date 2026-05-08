import AppKit
import Foundation
import RemoteDockCore
import UniformTypeIdentifiers

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
        if let imageItem = currentClipboardImageItem() {
            return imageItem
        }

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

    private func currentClipboardImageItem() -> ClipboardItem? {
        let sourceAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let imagePayload = imagePayload(from: pasteboard),
              let item = ClipboardHistoryReducer.makeImageItem(
                representation: imagePayload.representation,
                metadata: imagePayload.metadata,
                sourceAppBundleId: sourceAppBundleId,
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
            .filter { item in
                switch item.contentType {
                case .text:
                    return !item.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                case .image:
                    return item.primaryImageRepresentation != nil
                }
            }
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

    private func imagePayload(from pasteboard: NSPasteboard) -> ClipboardImagePayload? {
        let candidateTypes = pasteboard.types?.filter(Self.shouldCaptureImagePasteboardType) ?? []

        for pasteboardType in candidateTypes {
            guard let data = pasteboard.data(forType: pasteboardType),
                  let image = NSImage(data: data),
                  let metadata = imageMetadata(
                    for: image,
                    data: data,
                    pasteboardType: pasteboardType
                  ) else {
                continue
            }

            let representation = ClipboardRepresentation(
                kind: ClipboardRepresentationKind(pasteboardTypeIdentifier: pasteboardType.rawValue),
                data: data
            )
            return ClipboardImagePayload(representation: representation, metadata: metadata)
        }

        guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
              let data = Self.pngData(for: image),
              let metadata = imageMetadata(
                for: image,
                data: data,
                pasteboardType: .png
              ) else {
            return imageFilePayload(from: pasteboard)
        }

        let representation = ClipboardRepresentation(kind: .png, data: data)
        return ClipboardImagePayload(representation: representation, metadata: metadata)
    }

    private func imageFilePayload(from pasteboard: NSPasteboard) -> ClipboardImagePayload? {
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return nil
        }

        for url in objects {
            guard url.isFileURL,
                  Self.fileURLLooksLikeImage(url),
                  let fileSize = Self.fileSize(for: url),
                  fileSize <= policy.maxImageBytes,
                  let data = try? Data(contentsOf: url),
                  let image = NSImage(data: data),
                  let metadata = imageMetadata(
                    for: image,
                    data: data,
                    pasteboardType: Self.pasteboardType(forImageFileURL: url)
                  ) else {
                continue
            }

            let representation = ClipboardRepresentation(
                kind: ClipboardRepresentationKind(
                    pasteboardTypeIdentifier: Self.pasteboardType(forImageFileURL: url).rawValue
                ),
                data: data
            )
            return ClipboardImagePayload(representation: representation, metadata: metadata)
        }

        return nil
    }

    private func imageMetadata(
        for image: NSImage,
        data: Data,
        pasteboardType: NSPasteboard.PasteboardType
    ) -> ClipboardImageMetadata? {
        let pixelSize = Self.pixelSize(for: image)
        guard pixelSize.width > 0,
              pixelSize.height > 0 else {
            return nil
        }

        let thumbnailData = Self.thumbnailPNGData(for: image, maximumPixelDimension: 256)
        let thumbnailSize = thumbnailData.flatMap { NSImage(data: $0) }.map(Self.pixelSize(for:))

        return ClipboardImageMetadata(
            formatIdentifier: ClipboardRepresentationKind(
                pasteboardTypeIdentifier: pasteboardType.rawValue
            ).pasteboardTypeIdentifier,
            pixelWidth: Int(pixelSize.width.rounded()),
            pixelHeight: Int(pixelSize.height.rounded()),
            bytesLength: data.count,
            thumbnailPNGData: thumbnailData,
            thumbnailPixelWidth: thumbnailSize.map { Int($0.width.rounded()) },
            thumbnailPixelHeight: thumbnailSize.map { Int($0.height.rounded()) }
        )
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

        if item.contentType != existingItem.contentType {
            return item.contentType == .image
        }

        let richByteCount = item.richRepresentations.reduce(0) { $0 + $1.data.count }
        let existingRichByteCount = existingItem.richRepresentations.reduce(0) { $0 + $1.data.count }
        if richByteCount != existingRichByteCount {
            return richByteCount > existingRichByteCount
        }

        return item.richRepresentations.count > existingItem.richRepresentations.count
    }

    private nonisolated static func shouldCaptureImagePasteboardType(_ pasteboardType: NSPasteboard.PasteboardType) -> Bool {
        let kind = ClipboardRepresentationKind(pasteboardTypeIdentifier: pasteboardType.rawValue)
        let lowercasedIdentifier = pasteboardType.rawValue.lowercased()
        return kind.isImage ||
            lowercasedIdentifier == NSPasteboard.PasteboardType.tiff.rawValue.lowercased() ||
            lowercasedIdentifier == NSPasteboard.PasteboardType.png.rawValue.lowercased()
    }

    private nonisolated static func fileURLLooksLikeImage(_ url: URL) -> Bool {
        guard let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }

        return contentType.conforms(to: .image)
    }

    private nonisolated static func fileSize(for url: URL) -> Int? {
        guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }

        return fileSize
    }

    private nonisolated static func pasteboardType(forImageFileURL url: URL) -> NSPasteboard.PasteboardType {
        guard let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return .png
        }

        if contentType.conforms(to: .png) {
            return .png
        }
        if contentType.conforms(to: .jpeg) {
            return NSPasteboard.PasteboardType("public.jpeg")
        }
        if contentType.conforms(to: .tiff) {
            return .tiff
        }
        if contentType.conforms(to: .gif) {
            return NSPasteboard.PasteboardType("com.compuserve.gif")
        }
        if contentType.identifier == "public.heic" {
            return NSPasteboard.PasteboardType("public.heic")
        }
        if contentType.identifier == "public.heif" {
            return NSPasteboard.PasteboardType("public.heif")
        }

        return .png
    }

    private nonisolated static func pixelSize(for image: NSImage) -> CGSize {
        if let representation = image.representations.max(by: {
            ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh)
        }), representation.pixelsWide > 0, representation.pixelsHigh > 0 {
            return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        return image.size
    }

    private nonisolated static func thumbnailPNGData(
        for image: NSImage,
        maximumPixelDimension: CGFloat
    ) -> Data? {
        let pixelSize = pixelSize(for: image)
        guard pixelSize.width > 0, pixelSize.height > 0 else {
            return nil
        }

        let scale = min(1, maximumPixelDimension / max(pixelSize.width, pixelSize.height))
        let targetSize = NSSize(
            width: max(1, floor(pixelSize.width * scale)),
            height: max(1, floor(pixelSize.height * scale))
        )
        let renderedImage = NSImage(size: targetSize)

        renderedImage.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: targetSize).fill()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        renderedImage.unlockFocus()

        return pngData(for: renderedImage)
    }

    private nonisolated static func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
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

private struct ClipboardImagePayload {
    var representation: ClipboardRepresentation
    var metadata: ClipboardImageMetadata
}
