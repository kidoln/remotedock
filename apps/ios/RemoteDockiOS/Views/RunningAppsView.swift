import RemoteDockCore
import SwiftUI

struct RunningAppsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        PhonePageSurface {
            if appModel.runningApps.apps.isEmpty {
                PhoneEmptyState(title: appModel.settings.remoteLanguage.localizedString("ios.running.empty"), systemImage: "rectangle.stack")
            } else {
                PhoneIconGrid(gridCount: appModel.settings.iconGridCount) { iconSize in
                    ForEach(appModel.runningApps.apps) { app in
                        let isActive = appModel.runningApps.activeAppId == app.id

                        Button {
                            appModel.activate(app)
                        } label: {
                            AppIconView(
                                title: app.displayName,
                                isActive: isActive,
                                image: appModel.iconImage(for: app)
                            )
                            .frame(width: iconSize, height: iconSize)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(app.displayName)
                        .accessibilityValue(isActive ? appModel.settings.remoteLanguage.localizedString("ios.accessibility.currentActive") : "")
                        .accessibilityHint(appModel.settings.remoteLanguage.localizedString("ios.accessibility.switchToMacApp"))
                    }
                }
            }
        }
    }
}
