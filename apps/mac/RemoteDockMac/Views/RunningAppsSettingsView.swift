import SwiftUI

struct RunningAppsSettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(appModel.language.localizedString("settings.pane.runningApps"))
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    appModel.refresh()
                } label: {
                    Label(appModel.language.localizedString("action.refresh"), systemImage: "arrow.clockwise")
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
                    .help(appModel.language.localizedString(appModel.isRunningAppHidden(app) ? "settings.running.hiddenHelp" : "settings.running.visibleHelp"))
                }
                .padding(.vertical, 4)
            }
        }
    }
}
