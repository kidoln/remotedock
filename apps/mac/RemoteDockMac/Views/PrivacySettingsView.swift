import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("隐私与权限")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    value: appModel.permissionStatus.accessibilityGranted ? "已授权" : "未授权",
                    symbol: appModel.permissionStatus.accessibilityGranted ? "checkmark.shield" : "exclamationmark.triangle"
                ) {
                    appModel.openAccessibilitySettings()
                }

                permissionRow(
                    title: "Local Network",
                    value: appModel.permissionStatus.localNetworkStatusText,
                    symbol: "network"
                )

                permissionRow(
                    title: "Notifications",
                    value: appModel.permissionStatus.notificationsStatusText,
                    symbol: "bell"
                )
            }

            Divider()

            Toggle("剪贴板同步", isOn: $appModel.clipboardSyncEnabled)

            HStack {
                Text("已缓存 \(appModel.clipboardItems.count) 条剪贴板记录")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    appModel.clearClipboardHistory()
                } label: {
                    Label("清空", systemImage: "trash")
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        value: String,
        symbol: String,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)

            Text(title)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)

            if let action {
                Button("打开") {
                    action()
                }
            }
        }
    }
}
