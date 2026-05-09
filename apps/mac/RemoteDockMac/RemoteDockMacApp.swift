import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var appModel: MacAppModel!
    private var statusItemController: StatusItemController?
    var clipboardHistoryPanelController: ClipboardHistoryPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化 appModel
        appModel = MacAppModel()
        statusItemController = StatusItemController(appModel: appModel)
        clipboardHistoryPanelController = ClipboardHistoryPanelController(appModel: appModel)

        // 应用启动时显示设置窗口
        NSApplication.shared.setActivationPolicy(.regular)
        statusItemController?.showSettingsWindow()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
    }

    func applicationDidResignActive(_ notification: Notification) {
    }
}

@main
struct RemoteDockMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            if let appModel = appDelegate.appModel {
                SettingsView()
                    .environmentObject(appModel)
                    .environment(\.locale, Locale(identifier: appModel.language.localeIdentifier))
                    .frame(minWidth: 760, minHeight: 500)
            }
        }
    }
}

@MainActor
private final class StatusItemController: NSObject, ObservableObject {
    private let appModel: MacAppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var settingsWindowController: SettingsWindowController?

    init(appModel: MacAppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Remote Dock")
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView { [weak self] in
                self?.popover.performClose(nil)
                self?.showSettingsWindow()
            }
            .environmentObject(appModel)
            .environment(\.locale, Locale(identifier: appModel.language.localeIdentifier))
            .frame(width: 320)
        )
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApplication.shared.currentEvent
        let shouldOpenMenu = event?.type == .rightMouseUp ||
            event?.modifierFlags.contains(.control) == true

        if shouldOpenMenu {
            togglePopover(relativeTo: sender)
        } else {
            popover.performClose(nil)
            showSettingsWindow()
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            appModel.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appModel: appModel) {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }

        NSApplication.shared.setActivationPolicy(.regular)
        settingsWindowController?.showSettingsWindow()
    }
}

@MainActor
private final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(appModel: MacAppModel, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let rootView = SettingsView()
            .environmentObject(appModel)
            .environment(\.locale, Locale(identifier: appModel.language.localeIdentifier))
            .frame(minWidth: 760, minHeight: 500)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Remote Dock"
        window.identifier = NSUserInterfaceItemIdentifier("RemoteDockSettingsWindow")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 760, height: 500)
        window.setContentSize(NSSize(width: 800, height: 500))
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.center()

        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showSettingsWindow() {
        guard let window else {
            return
        }

        if !window.isVisible {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
