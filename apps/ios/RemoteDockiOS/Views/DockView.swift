import SwiftUI

struct DockView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        PhonePageSurface {
            if appModel.dock.apps.isEmpty {
                PhoneEmptyState(title: "暂无 Dock 应用", systemImage: "dock.rectangle")
            } else {
                PhoneIconGrid(gridCount: appModel.settings.iconGridCount) { iconSize in
                    ForEach(appModel.dock.apps) { app in
                        Button {
                            appModel.activate(app)
                        } label: {
                            AppIconView(
                                title: app.displayName,
                                isActive: appModel.dock.lastActivatedAppId == app.id,
                                image: appModel.iconImage(for: app)
                            )
                            .frame(width: iconSize, height: iconSize)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(app.displayName)
                        .accessibilityHint("切换到 Mac 上的这个应用")
                    }
                }
            }
        }
    }
}
