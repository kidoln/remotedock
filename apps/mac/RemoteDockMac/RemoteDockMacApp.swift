import SwiftUI

@main
struct RemoteDockMacApp: App {
    @StateObject private var appModel = MacAppModel()

    var body: some Scene {
        MenuBarExtra("Remote Dock", systemImage: appModel.menuBarSystemImage) {
            MenuBarContentView()
                .environmentObject(appModel)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(minWidth: 620, minHeight: 440)
        }
    }
}
