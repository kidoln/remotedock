import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DockView()
                .tabItem {
                    Label("Dock", systemImage: "dock.rectangle")
                }

            RunningAppsView()
                .tabItem {
                    Label("Running", systemImage: "rectangle.stack")
                }

            ClipboardView()
                .tabItem {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
