import SwiftUI

struct DockView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 96), spacing: 18)
    ]

    var body: some View {
        NavigationStack {
            PhonePageSurface {
                ScrollView {
                    if appModel.dock.apps.isEmpty {
                        PhoneEmptyState(title: "暂无 Dock 应用", systemImage: "dock.rectangle")
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(appModel.dock.apps) { app in
                                Button {
                                    appModel.activate(app)
                                } label: {
                                    AppIconView(
                                        title: app.displayName,
                                        isActive: appModel.dock.lastActivatedAppId == app.id,
                                        image: appModel.iconImage(for: app)
                                    )
                                    .frame(width: 62, height: 62)
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(PhoneIconWellBackground(isActive: appModel.dock.lastActivatedAppId == app.id))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(app.displayName)
                                .accessibilityHint("切换到 Mac 上的这个应用")
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                    }
                }
            }
            .navigationTitle("Dock")
            .safeAreaInset(edge: .top) {
                ConnectionBanner()
            }
        }
    }
}
