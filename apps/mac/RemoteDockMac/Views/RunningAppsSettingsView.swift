import SwiftUI

struct RunningAppsSettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("运行中应用")
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
                    Image(systemName: app.isActive ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(app.isActive ? .green : .secondary)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.displayName)
                        Text("\(app.bundleIdentifier) · pid \(app.pid)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        appModel.activateRunningApp(app)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .help("切换")
                }
                .padding(.vertical, 4)
            }
        }
    }
}
