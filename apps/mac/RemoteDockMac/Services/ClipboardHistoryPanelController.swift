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
        window.setContentSize(NSSize(width: 760, height: 480))
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
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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

    private func selectSecondItem() {
        let filteredItems = filteredItems
        selectedItemID = filteredItems.dropFirst().first?.id ?? filteredItems.first?.id
    }

    private func selectFirstItem() {
        selectedItemID = filteredItems.first?.id
    }
}

private struct ClipboardHistoryPanelView: View {
    @ObservedObject var store: ClipboardHistoryPanelStore
    var paste: (ClipboardItem) -> Void
    var close: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField

            Rectangle()
                .fill(ClipboardPanelPalette.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                historyList
                    .frame(width: 340)

                Rectangle()
                    .fill(ClipboardPanelPalette.border)
                    .frame(width: 1)

                detailPane
            }
        }
        .frame(width: 760, height: 480)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(ClipboardPanelPalette.background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(ClipboardPanelPalette.border, lineWidth: 1)
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ClipboardPanelPalette.mutedText)

            TextField("搜索剪贴板历史", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(ClipboardPanelPalette.primaryText)
                .focused($isSearchFocused)
                .onSubmit {
                    if let selectedItem = store.selectedItem {
                        paste(selectedItem)
                    }
                }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.filteredItems) { item in
                        ClipboardHistoryPanelRow(
                            item: item,
                            isSelected: item.id == store.selectedItemID
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
                .padding(10)
            }
            .background(ClipboardPanelPalette.listBackground)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedItem.sourceAppBundleId ?? "未知来源")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ClipboardPanelPalette.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(selectedItem.createdAt, style: .date)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(ClipboardPanelPalette.mutedText)
                    }

                    Spacer()

                    Text(selectedItem.createdAt, style: .time)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(ClipboardPanelPalette.mutedText)
                }

                ScrollView {
                    Text(selectedItem.plainText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(ClipboardPanelPalette.primaryText)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.18))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ClipboardPanelPalette.border, lineWidth: 1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ClipboardPanelPalette.detailBackground)
        } else {
            Text("没有匹配的剪贴板内容")
                .font(.system(size: 14))
                .foregroundStyle(ClipboardPanelPalette.mutedText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ClipboardPanelPalette.detailBackground)
        }
    }
}

private struct ClipboardHistoryPanelRow: View {
    var item: ClipboardItem
    var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.plainText)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isSelected ? .white : ClipboardPanelPalette.primaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.createdAt, style: .time)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? .white.opacity(0.72) : ClipboardPanelPalette.mutedText)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? ClipboardPanelPalette.accent : Color.white.opacity(0.001))
        }
        .contentShape(Rectangle())
    }
}

private enum ClipboardPanelPalette {
    static let background = Color(nsColor: NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.14, alpha: 0.98))
    static let listBackground = Color(nsColor: NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.12, alpha: 0.98))
    static let detailBackground = Color(nsColor: NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.15, alpha: 0.98))
    static let border = Color.white.opacity(0.12)
    static let accent = Color(nsColor: NSColor.systemBlue)
    static let primaryText = Color.white.opacity(0.88)
    static let secondaryText = Color.white.opacity(0.68)
    static let mutedText = Color.white.opacity(0.44)
}
