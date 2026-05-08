import SwiftUI

struct PinnedAppsSettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("常用应用")
                    .font(.title2.weight(.semibold))

                Spacer()

                Text("请在新版设置页中通过添加菜单选择应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(appModel.pinnedApps) { app in
                    HStack(spacing: 12) {
                        MacAppIconView(
                            bundleIdentifier: app.bundleIdentifier,
                            appPath: app.appPath,
                            size: 32
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                                .font(.body)
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            appModel.activatePinnedApp(app)
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .help("激活")

                        Button(role: .destructive) {
                            appModel.removePinnedApp(app)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("移除")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
