import SwiftUI
import UIKit

@main
struct RemoteDockiOSApp: App {
    @UIApplicationDelegateAdaptor(RemoteDockAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appModel = RemoteDockClientStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .environment(\.locale, Locale(identifier: appModel.settings.remoteLanguage.localeIdentifier))
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

final class RemoteDockAppDelegate: NSObject, UIApplicationDelegate {
    static var supportedInterfaceOrientations = InterfaceOrientationLock.defaultMask

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.supportedInterfaceOrientations
    }
}

@MainActor
enum InterfaceOrientationLock {
    static var defaultMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    static func lockToPortrait() {
        RemoteDockAppDelegate.supportedInterfaceOrientations = .portrait

        if #available(iOS 16.0, *) {
            requestGeometryUpdate(.portrait)
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    static func unlock() {
        RemoteDockAppDelegate.supportedInterfaceOrientations = defaultMask

        if #available(iOS 16.0, *) {
            requestGeometryUpdate(defaultMask)
        }
    }

    @available(iOS 16.0, *)
    private static func requestGeometryUpdate(_ orientations: UIInterfaceOrientationMask) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .forEach { scene in
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
            }

        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}
