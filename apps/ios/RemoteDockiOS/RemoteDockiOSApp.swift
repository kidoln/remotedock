import SwiftUI

@main
struct RemoteDockiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = RemoteDockClientStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .task {
                    appModel.startIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appModel.applicationDidBecomeActive()
                    }
                }
        }
    }
}
