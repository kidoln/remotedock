import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(appModel.language.localizedString("settings.privacy.title"))
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    value: appModel.language.localizedString(
                        appModel.permissionStatus.accessibilityGranted ? "value.authorized" : "value.unauthorized"
                    ),
                    symbol: appModel.permissionStatus.accessibilityGranted ? "checkmark.shield" : "exclamationmark.triangle"
                ) {
                    appModel.openAccessibilitySettings()
                }

                permissionRow(
                    title: "Local Network",
                    value: appModel.language.localizedString("settings.privacy.localNetworkPrompt"),
                    symbol: "network"
                )

                permissionRow(
                    title: "Notifications",
                    value: appModel.language.localizedString("settings.privacy.notificationsOptional"),
                    symbol: "bell"
                )
            }

            Divider()

            Toggle(appModel.language.localizedString("settings.privacy.clipboardSync"), isOn: $appModel.clipboardSyncEnabled)

            HStack {
                Text(appModel.language.formattedLocalizedString("settings.privacy.cachedClipboardCount", appModel.clipboardItems.count))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    appModel.clearClipboardHistory()
                } label: {
                    Label(appModel.language.localizedString("action.clear"), systemImage: "trash")
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
                Button(appModel.language.localizedString("action.open")) {
                    action()
                }
            }
        }
    }
}
