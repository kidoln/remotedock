import AppKit
import Carbon
import RemoteDockCore
import SwiftUI

@MainActor
final class ClipboardHistoryPanelController {
    private let appModel: MacAppModel
    private let store = ClipboardHistoryPanelStore()
    private let commandExecutor = MacCommandExecutor()
    private var window: NSWindow?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localEventMonitor: Any?
    private var targetApplication: NSRunningApplication?

    private nonisolated static let hotKeySignature: OSType = 0x45524448
    private nonisolated static let hotKeyID: UInt32 = 1

    init(appModel: MacAppModel) {
        self.appModel = appModel
        appModel.clipboardHistoryShortcutDidChange = { [weak self] shortcut in
            return self?.registerHotKey(shortcut) == true
        }
        installHotKeyHandler()
        appModel.updateClipboardHistoryShortcutRegistration(isRegistered: registerHotKey(appModel.clipboardHistorySettings.shortcut))
    }

    func showPanel() {
        if window?.isVisible != true {
            targetApplication = currentPasteTarget()
        }
        appModel.refresh()
        store.load(items: appModel.clipboardItems)
        appModel.clearClipboardHistoryPanelError()

        let panelWindow = window ?? makeWindow()
        window = panelWindow
        installLocalEventMonitor()

        if !panelWindow.isVisible {
            position(panelWindow)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        panelWindow.makeKeyAndOrderFront(nil)
        panelWindow.orderFrontRegardless()
    }

    private func hidePanel() {
        window?.orderOut(nil)
        removeLocalEventMonitor()
    }

    private func makeWindow() -> NSWindow {
        let rootView = ClipboardHistoryPanelView(
            store: store,
            paste: { [weak self] item in
                self?.paste(item)
            },
            close: { [weak self] in
                self?.hidePanel()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = ClipboardHistoryPanelWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier("RemoteDockClipboardHistoryPanel")
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.minSize = ClipboardHistoryPanelWindow.minimumPanelSize
        window.setContentSize(ClipboardHistoryPanelWindow.defaultPanelSize)
        window.refreshResizeCursorArea()
        return window
    }

    private func position(_ window: NSWindow) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2 + 40
        )
        window.setFrameOrigin(origin)
    }

    private func paste(_ item: ClipboardItem) {
        hidePanel()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let promotedItem = self.appModel.promoteClipboardHistoryItem(item)

            if let targetApplication = self.targetApplication,
               !targetApplication.isTerminated {
                targetApplication.activate(options: [.activateAllWindows])
                let didActivate = await self.waitForActivation(of: targetApplication)
                guard didActivate else {
                    self.appModel.reportClipboardHistoryPanelError("无法激活目标应用")
                    self.targetApplication = nil
                    return
                }
            }

            do {
                try await self.commandExecutor.pasteIntoFrontmostApp(promotedItem.plainText)
            } catch {
                self.appModel.reportClipboardHistoryPanelError(Self.pasteErrorMessage(for: error))
            }
            self.targetApplication = nil
        }
    }

    private func currentPasteTarget() -> NSRunningApplication? {
        let currentApplication = NSRunningApplication.current
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        guard frontmostApplication?.processIdentifier != currentApplication.processIdentifier else {
            return targetApplication
        }
        return frontmostApplication
    }

    private func waitForActivation(of application: NSRunningApplication) async -> Bool {
        for _ in 0..<12 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                return true
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private nonisolated static func pasteErrorMessage(for error: Error) -> String {
        if case RemoteDockError.permissionDenied = error {
            return "需要辅助功能权限才能粘贴"
        }
        return "粘贴失败：\(String(describing: error))"
    }

    private func pasteSelectedItem() {
        guard let selectedItem = store.selectedItem else {
            return
        }
        paste(selectedItem)
    }

    private func installLocalEventMonitor() {
        guard localEventMonitor == nil else {
            return
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window else {
                return event
            }

            if let zoomAction = Self.textZoomAction(for: event) {
                self.store.performTextZoom(zoomAction)
                return nil
            }

            if let shortcutIndex = Self.commandNumberShortcutIndex(for: event),
               let item = self.store.itemForCommandShortcut(index: shortcutIndex) {
                self.paste(item)
                return nil
            }

            switch Int(event.keyCode) {
            case kVK_DownArrow:
                self.store.moveSelection(by: 1)
                return nil
            case kVK_UpArrow:
                self.store.moveSelection(by: -1)
                return nil
            case kVK_Return:
                self.pasteSelectedItem()
                return nil
            case kVK_Escape:
                self.hidePanel()
                return nil
            default:
                return event
            }
        }
    }

    private func removeLocalEventMonitor() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    private nonisolated static func commandNumberShortcutIndex(for event: NSEvent) -> Int? {
        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowedFlags = relevantFlags.subtracting([.command, .capsLock, .numericPad])
        guard relevantFlags.contains(.command),
              disallowedFlags.isEmpty else {
            return nil
        }

        switch Int(event.keyCode) {
        case kVK_ANSI_1: return 0
        case kVK_ANSI_2: return 1
        case kVK_ANSI_3: return 2
        case kVK_ANSI_4: return 3
        case kVK_ANSI_5: return 4
        case kVK_ANSI_6: return 5
        case kVK_ANSI_7: return 6
        case kVK_ANSI_8: return 7
        case kVK_ANSI_9: return 8
        case kVK_ANSI_Keypad1: return 0
        case kVK_ANSI_Keypad2: return 1
        case kVK_ANSI_Keypad3: return 2
        case kVK_ANSI_Keypad4: return 3
        case kVK_ANSI_Keypad5: return 4
        case kVK_ANSI_Keypad6: return 5
        case kVK_ANSI_Keypad7: return 6
        case kVK_ANSI_Keypad8: return 7
        case kVK_ANSI_Keypad9: return 8
        default: return nil
        }
    }

    private nonisolated static func textZoomAction(for event: NSEvent) -> ClipboardPanelTextZoomAction? {
        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowedFlags = relevantFlags.subtracting([.command, .shift, .capsLock, .numericPad])
        guard relevantFlags.contains(.command),
              disallowedFlags.isEmpty else {
            return nil
        }

        switch Int(event.keyCode) {
        case kVK_ANSI_Equal, kVK_ANSI_KeypadPlus:
            return .zoomIn
        case kVK_ANSI_Minus, kVK_ANSI_KeypadMinus:
            return .zoomOut
        case kVK_ANSI_0, kVK_ANSI_Keypad0:
            return .reset
        default:
            return nil
        }
    }

    private func installHotKeyHandler() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            clipboardHistoryHotKeyHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    @discardableResult
    private func registerHotKey(_ shortcut: ClipboardHistoryShortcut) -> Bool {
        unregisterHotKey()

        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: Self.hotKeyID
        )
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            hotKeyRef = nil
            return false
        }

        return true
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    fileprivate func handleHotKey(signature: OSType, id: UInt32) {
        guard signature == Self.hotKeySignature,
              id == Self.hotKeyID else {
            return
        }

        showPanel()
    }
}

private func clipboardHistoryHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event,
          let userData else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else {
        return status
    }

    let controller = Unmanaged<ClipboardHistoryPanelController>
        .fromOpaque(userData)
        .takeUnretainedValue()
    Task { @MainActor in
        controller.handleHotKey(signature: hotKeyID.signature, id: hotKeyID.id)
    }
    return noErr
}

private final class ClipboardHistoryPanelWindow: NSPanel {
    static let defaultPanelSize = NSSize(width: 718, height: 431)
    static let minimumPanelSize = NSSize(width: 560, height: 336)

    private var resizeState: ResizeState?
    private var resizeCursorTrackingArea: NSTrackingArea?
    private let resizeHandleSize: CGFloat = 44

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if beginResizingIfNeeded(with: event) {
                return
            }
        case .leftMouseDragged:
            if resizeState != nil {
                resize(with: event)
                return
            }
        case .leftMouseUp:
            resizeState = nil
        case .mouseMoved:
            updateCursor(for: event)
        case .cursorUpdate:
            updateCursor(for: event)
        default:
            break
        }

        super.sendEvent(event)
    }

    private func beginResizingIfNeeded(with event: NSEvent) -> Bool {
        guard isInResizeHandle(event.locationInWindow) else {
            return false
        }

        resizeState = ResizeState(
            initialFrame: frame,
            initialMouseLocation: NSEvent.mouseLocation
        )
        return true
    }

    private func resize(with event: NSEvent) {
        guard let resizeState else {
            return
        }

        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - resizeState.initialMouseLocation.x
        let deltaY = currentMouseLocation.y - resizeState.initialMouseLocation.y
        let initialFrame = resizeState.initialFrame
        let aspectRatio = Self.defaultPanelSize.width / Self.defaultPanelSize.height
        let heightDrivenWidth = (initialFrame.height - deltaY) * aspectRatio
        let proposedWidth = abs(deltaX) >= abs(deltaY) ? initialFrame.width + deltaX : heightDrivenWidth
        let nextWidth = max(minSize.width, proposedWidth)
        let nextHeight = max(minSize.height, nextWidth / aspectRatio)
        let nextFrame = NSRect(
            x: initialFrame.minX,
            y: initialFrame.maxY - nextHeight,
            width: nextHeight * aspectRatio,
            height: nextHeight
        )

        setFrame(nextFrame, display: true)
        refreshResizeCursorArea()
    }

    private func updateCursor(for event: NSEvent) {
        if isInResizeHandle(event.locationInWindow) {
            Self.resizeCursor.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func isInResizeHandle(_ point: NSPoint) -> Bool {
        guard point.x >= 0,
              point.y >= 0,
              point.x <= frame.width,
              point.y <= frame.height else {
            return false
        }

        return point.x >= frame.width - resizeHandleSize && point.y <= resizeHandleSize
    }

    fileprivate func refreshResizeCursorArea() {
        guard let contentView else {
            return
        }

        if let resizeCursorTrackingArea {
            contentView.removeTrackingArea(resizeCursorTrackingArea)
        }

        contentView.discardCursorRects()
        contentView.addCursorRect(resizeHandleRect(in: contentView.bounds), cursor: Self.resizeCursor)

        let trackingArea = NSTrackingArea(
            rect: resizeHandleRect(in: contentView.bounds),
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
        resizeCursorTrackingArea = trackingArea
    }

    private func resizeHandleRect(in bounds: NSRect) -> NSRect {
        NSRect(
            x: max(0, bounds.maxX - resizeHandleSize),
            y: bounds.minY,
            width: min(resizeHandleSize, bounds.width),
            height: min(resizeHandleSize, bounds.height)
        )
    }

    private struct ResizeState {
        var initialFrame: NSRect
        var initialMouseLocation: NSPoint
    }

    private static var resizeCursor: NSCursor {
        NSCursor.frameResize(position: .bottomRight, directions: .all)
    }
}

private enum ClipboardPanelTextZoomAction {
    case zoomIn
    case zoomOut
    case reset
}

@MainActor
private final class ClipboardHistoryPanelStore: ObservableObject {
    @Published var searchText = "" {
        didSet {
            if oldValue != searchText {
                selectFirstItem()
            }
        }
    }
    @Published private(set) var items: [ClipboardItem] = []
    @Published var selectedItemID: String?
    @Published private(set) var textScale: CGFloat = 1

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return items
        }

        return items.filter { item in
            ClipboardSearchMatcher.matches(item, query: query)
        }
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else {
            return nil
        }
        return filteredItems.first { $0.id == selectedItemID }
    }

    func load(items: [ClipboardItem]) {
        self.items = items.sorted { $0.createdAt > $1.createdAt }
        searchText = ""
        selectSecondItem()
    }

    func select(_ item: ClipboardItem) {
        selectedItemID = item.id
    }

    func moveSelection(by offset: Int) {
        let filteredItems = filteredItems
        guard !filteredItems.isEmpty else {
            selectedItemID = nil
            return
        }

        let currentIndex = selectedItemID.flatMap { id in
            filteredItems.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), filteredItems.count - 1)
        selectedItemID = filteredItems[nextIndex].id
    }

    func itemForCommandShortcut(index: Int) -> ClipboardItem? {
        let filteredItems = filteredItems
        guard (0..<min(filteredItems.count, 9)).contains(index) else {
            return nil
        }
        return filteredItems[index]
    }

    func performTextZoom(_ action: ClipboardPanelTextZoomAction) {
        switch action {
        case .zoomIn:
            textScale = min(Self.maximumTextScale, textScale + Self.textScaleStep)
        case .zoomOut:
            textScale = max(Self.minimumTextScale, textScale - Self.textScaleStep)
        case .reset:
            textScale = 1
        }
    }

    private func selectSecondItem() {
        let filteredItems = filteredItems
        selectedItemID = filteredItems.dropFirst().first?.id ?? filteredItems.first?.id
    }

    private func selectFirstItem() {
        selectedItemID = filteredItems.first?.id
    }

    private static let minimumTextScale: CGFloat = 0.75
    private static let maximumTextScale: CGFloat = 1.65
    private static let textScaleStep: CGFloat = 0.1
}

private struct ClipboardHistoryPanelView: View {
    @ObservedObject var store: ClipboardHistoryPanelStore
    var paste: (ClipboardItem) -> Void
    var close: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField

            HStack(spacing: 0) {
                historyList
                    .frame(maxWidth: .infinity)

                detailPane
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(
            minWidth: ClipboardHistoryPanelWindow.minimumPanelSize.width,
            minHeight: ClipboardHistoryPanelWindow.minimumPanelSize.height
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ClipboardPanelPalette.background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ClipboardPanelPalette.border, lineWidth: 1)
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private var searchField: some View {
        TextField("", text: $store.searchText)
            .textFieldStyle(.plain)
            .font(.system(size: 18 * store.textScale, weight: .regular))
            .foregroundStyle(ClipboardPanelPalette.primaryText)
            .focused($isSearchFocused)
            .onSubmit {
                if let selectedItem = store.selectedItem {
                    paste(selectedItem)
                }
            }
            .padding(.horizontal, 5)
            .frame(height: max(30, 30 * store.textScale))
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(ClipboardPanelPalette.searchBackground)
            }
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 8)
            .frame(height: max(47, 47 * store.textScale))
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardHistoryPanelRow(
                            item: item,
                            shortcutIndex: index < 9 ? index : nil,
                            isSelected: item.id == store.selectedItemID,
                            textScale: store.textScale
                        )
                        .id(item.id)
                        .onTapGesture {
                            store.select(item)
                        }
                        .onTapGesture(count: 2) {
                            paste(item)
                        }
                    }
                }
                .padding(.leading, 13)
                .padding(.trailing, 0)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .onChange(of: store.selectedItemID) { _, selectedItemID in
                guard let selectedItemID else {
                    return
                }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(selectedItemID, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedItem = store.selectedItem {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    Text(selectedItem.plainText)
                        .font(.system(size: 11.5 * store.textScale, weight: .regular, design: .monospaced))
                        .foregroundStyle(ClipboardPanelPalette.primaryText)
                        .textSelection(.enabled)
                        .lineSpacing(2 * store.textScale)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, 13)
                        .padding(.horizontal, 7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                ClipboardHistoryPanelSummary(item: selectedItem)
                    .environment(\.clipboardPanelTextScale, store.textScale)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("没有匹配的剪贴板内容")
                .font(.system(size: 14 * store.textScale))
                .foregroundStyle(ClipboardPanelPalette.mutedText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipboardHistoryPanelRow: View {
    var item: ClipboardItem
    var shortcutIndex: Int?
    var isSelected: Bool
    var textScale: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            MacAppIconView(
                bundleIdentifier: item.sourceAppBundleId ?? "",
                appPath: nil,
                size: 20
            )

            Text(item.plainText)
                .font(.system(size: 14.5 * textScale, weight: .regular))
                .foregroundStyle(isSelected ? .white : ClipboardPanelPalette.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let trailingLabel {
                Text(trailingLabel)
                    .font(.system(size: 14 * textScale, weight: .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.95) : ClipboardPanelPalette.shortcutText)
                    .frame(width: 36, alignment: .trailing)
            } else {
                Color.clear
                    .frame(width: 36, height: 1)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: max(25, 25 * textScale), alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected ? ClipboardPanelPalette.accent : Color.white.opacity(0.001))
        }
        .contentShape(Rectangle())
    }

    private var trailingLabel: String? {
        if isSelected {
            return "↵"
        }
        guard let shortcutIndex else {
            return nil
        }
        return "⌘\(shortcutIndex + 1)"
    }
}

private struct ClipboardHistoryPanelSummary: View {
    @Environment(\.clipboardPanelTextScale) private var textScale

    var item: ClipboardItem

    var body: some View {
        VStack(spacing: 5) {
            Text(metricsText)
            Text(copiedText)
        }
        .font(.system(size: 11 * textScale, weight: .regular))
        .foregroundStyle(ClipboardPanelPalette.mutedText)
        .lineLimit(1)
    }

    private var metricsText: String {
        let wordCount = item.plainText.split(whereSeparator: \.isWhitespace).count
        let characterCount = item.plainText.count
        let wordLabel = wordCount == 1 ? "word" : "words"
        let characterLabel = characterCount == 1 ? "char" : "chars"
        return "\(wordCount) \(wordLabel); \(characterCount) \(characterLabel)"
    }

    private var copiedText: String {
        let time = Self.timeFormatter.string(from: item.createdAt)
        if Calendar.current.isDateInToday(item.createdAt) {
            return "Copied Today \(time)"
        }
        if Calendar.current.isDateInYesterday(item.createdAt) {
            return "Copied Yesterday \(time)"
        }
        return "Copied \(Self.dateFormatter.string(from: item.createdAt)) \(time)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

private struct ClipboardPanelTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private extension EnvironmentValues {
    var clipboardPanelTextScale: CGFloat {
        get { self[ClipboardPanelTextScaleKey.self] }
        set { self[ClipboardPanelTextScaleKey.self] = newValue }
    }
}

private enum ClipboardPanelPalette {
    static let background = Color(nsColor: NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 0.98))
    static let searchBackground = Color(nsColor: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.17, alpha: 1))
    static let border = Color.white.opacity(0.09)
    static let accent = Color(nsColor: NSColor(calibratedRed: 0.12, green: 0.47, blue: 0.52, alpha: 1))
    static let primaryText = Color.white.opacity(0.86)
    static let mutedText = Color.white.opacity(0.46)
    static let shortcutText = Color.white.opacity(0.40)
}
