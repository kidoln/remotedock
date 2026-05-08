import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        TabView {
            PinnedAppsSettingsView()
                .tabItem {
                    Label("Dock", systemImage: "dock.rectangle")
                }

            RunningAppsSettingsView()
                .tabItem {
                    Label("Running", systemImage: "rectangle.stack")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
        }
        .padding(20)
        .onAppear {
            appModel.refresh()
        }
    }
}
