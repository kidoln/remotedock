import SwiftUI

struct PinnedAppsSettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("常用应用")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    appModel.addFrontmostApplicationToPinnedApps()
                } label: {
                    Label("添加前台应用", systemImage: "plus")
                }
            }

            List {
                ForEach(appModel.pinnedApps) { app in
                    HStack(spacing: 12) {
                        Image(systemName: "app")
                            .frame(width: 28, height: 28)

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
