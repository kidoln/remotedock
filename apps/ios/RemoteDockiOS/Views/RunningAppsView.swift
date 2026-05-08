import SwiftUI

struct RunningAppsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        PhonePageSurface {
            if appModel.runningApps.apps.isEmpty {
                PhoneEmptyState(title: "暂无运行中的应用", systemImage: "rectangle.stack")
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
                        .accessibilityValue(isActive ? "当前活跃" : "")
                        .accessibilityHint("切换到 Mac 上的这个应用")
                    }
                }
            }
        }
    }
}
