import SwiftUI

struct RunningAppsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 96), spacing: 18)
    ]

    var body: some View {
        NavigationStack {
            PhonePageSurface {
                ScrollView {
                    if appModel.runningApps.apps.isEmpty {
                        PhoneEmptyState(title: "暂无运行中的应用", systemImage: "rectangle.stack")
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(appModel.runningApps.apps) { app in
                                let isSelected = app.isActive || appModel.runningApps.lastActivatedAppId == app.id

                                Button {
                                    appModel.activate(app)
                                } label: {
                                    AppIconView(
                                        title: app.displayName,
                                        isActive: isSelected,
                                        image: appModel.iconImage(for: app)
                                    )
                                    .frame(width: 62, height: 62)
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(PhoneIconWellBackground(isActive: isSelected))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(app.displayName)
                                .accessibilityValue(app.isActive ? "当前活跃" : "")
                                .accessibilityHint("切换到 Mac 上的这个应用")
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                    }
                }
            }
            .navigationTitle("Running")
            .safeAreaInset(edge: .top) {
                ConnectionBanner()
            }
        }
    }
}
