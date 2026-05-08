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
                if let pairedDeviceName = appModel.pairedDeviceName {
                    Label(pairedDeviceName, systemImage: "iphone")
                }
                Label(
                    appModel.permissionStatus.accessibilityGranted ? "Accessibility 已授权" : "Accessibility 未授权",
                    systemImage: appModel.permissionStatus.accessibilityGranted ? "checkmark.shield" : "exclamationmark.triangle"
                )
            }
            .font(.callout)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("常用应用")
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
                Button("设置") {
                    openSettings()
                }

                Spacer()

                Button("退出") {
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
            Text("macOS 宿主端")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var connectionText: String {
        switch appModel.connectionState {
        case .idle:
            "等待启动"
        case .discovering:
            "正在广播，等待 iPhone 连接"
        case .connecting:
            "正在连接"
        case let .connected(peer):
            "已连接 \(peer.displayName)"
        case .reconnecting:
            "正在重连"
        case .disconnected:
            "已断开"
        case let .failed(message):
            "连接失败 \(message)"
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
