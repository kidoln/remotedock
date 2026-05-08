import SwiftUI

@main
struct RemoteDockiOSApp: App {
    @StateObject private var appModel = RemoteDockClientStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
        }
    }
}
