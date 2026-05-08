import SwiftUI

struct RunningAppsSettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("运行应用")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    appModel.refresh()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }

            List(appModel.runningApps) { app in
                HStack(spacing: 12) {
                    MacAppIconView(
                        bundleIdentifier: app.bundleIdentifier,
                        appPath: nil,
                        isActive: app.isActive,
                        size: 32
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.displayName)
                        Text("\(app.bundleIdentifier) · pid \(app.pid)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        appModel.toggleRunningAppVisibility(app)
                    } label: {
                        Image(systemName: appModel.isRunningAppHidden(app) ? "eye.slash.fill" : "eye.fill")
                    }
                    .help(appModel.isRunningAppHidden(app) ? "已在手机端隐藏" : "将在手机端显示")
                }
                .padding(.vertical, 4)
            }
        }
    }
}
