import SwiftUI

struct RunningAppsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        NavigationStack {
            List(appModel.runningApps.apps) { app in
                Button {
                    appModel.activate(app)
                } label: {
                    HStack(spacing: 12) {
                        AppIconView(title: app.displayName, isActive: app.isActive)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.displayName)
                                .font(.body.weight(.medium))
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if app.isActive || appModel.runningApps.lastActivatedAppId == app.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Running")
            .safeAreaInset(edge: .top) {
                ConnectionBanner()
            }
        }
    }
}
