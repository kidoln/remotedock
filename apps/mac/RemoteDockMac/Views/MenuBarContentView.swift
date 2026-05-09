import RemoteDockCore
import RemoteDockTransport
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: MacAppModel
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(connectionText, systemImage: connectionSymbol)
                Label(appModel.language.formattedLocalizedString("mac.menu.pairingCode", appModel.pairingCode), systemImage: "key")
                if let pairedDeviceName = appModel.pairedDeviceName {
                    Label(pairedDeviceName, systemImage: "iphone")
                }
                Label(
                    appModel.language.localizedString(
                        appModel.permissionStatus.accessibilityGranted
                            ? "mac.menu.accessibilityGranted"
                            : "mac.menu.accessibilityDenied"
                    ),
                    systemImage: appModel.permissionStatus.accessibilityGranted ? "checkmark.shield" : "exclamationmark.triangle"
                )
            }
            .font(.callout)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(appModel.language.localizedString("settings.pane.pinnedApps"))
                    .font(.headline)

                ForEach(appModel.pinnedApps.prefix(6)) { app in
                    Button {
                        appModel.activatePinnedApp(app)
                    } label: {
                        HStack(spacing: 8) {
                            MacAppIconView(
                                bundleIdentifier: app.bundleIdentifier,
                                appPath: app.appPath,
                                size: 22
                            )
                            Text(app.displayName)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Button(appModel.language.localizedString("action.settings")) {
                    openSettings()
                }

                Spacer()

                Button(appModel.language.localizedString("action.quit")) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remote Dock")
                .font(.title3.weight(.semibold))
            Text(appModel.language.localizedString("mac.menu.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var connectionText: String {
        switch appModel.connectionState {
        case .idle:
            appModel.language.localizedString("connection.idle")
        case .discovering:
            appModel.language.localizedString("mac.connection.advertising")
        case .connecting:
            appModel.language.localizedString("connection.connecting")
        case let .connected(peer):
            appModel.language.formattedLocalizedString("connection.connected", peer.displayName)
        case .reconnecting:
            appModel.language.localizedString("connection.reconnecting")
        case .disconnected:
            appModel.language.localizedString("connection.disconnected")
        case let .failed(message):
            appModel.language.formattedLocalizedString("connection.failed", message)
        }
    }

    private var connectionSymbol: String {
        switch appModel.connectionState {
        case .connected:
            "checkmark.circle"
        case .failed:
            "xmark.octagon"
        default:
            "antenna.radiowaves.left.and.right"
        }
    }
}
