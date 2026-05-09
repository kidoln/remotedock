import SwiftUI

struct PinnedAppsSettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(appModel.language.localizedString("settings.pane.pinnedApps"))
                    .font(.title2.weight(.semibold))

                Spacer()

                Text(appModel.language.localizedString("settings.pinned.legacyHint"))
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
                        .help(appModel.language.localizedString("action.activate"))

                        Button(role: .destructive) {
                            appModel.removePinnedApp(app)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help(appModel.language.localizedString("action.remove"))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
