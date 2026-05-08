import AppKit
import SwiftUI

@main
struct RemoteDockMacApp: App {
    @StateObject private var appModel: MacAppModel
    @StateObject private var statusItemController: StatusItemController

    init() {
        let appModel = MacAppModel()
        _appModel = StateObject(wrappedValue: appModel)
        _statusItemController = StateObject(wrappedValue: StatusItemController(appModel: appModel))
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(minWidth: 760, minHeight: 500)
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

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appModel: appModel)
        }

        settingsWindowController?.showSettingsWindow()
    }
}

@MainActor
private final class SettingsWindowController: NSWindowController {
    init(appModel: MacAppModel) {
        let rootView = SettingsView()
            .environmentObject(appModel)
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
}
