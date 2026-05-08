import AppKit
import RemoteDockCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: MacAppModel
    @State private var selection: SettingsPane = .pinnedApps
    @State private var isAppPickerPresented = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(SettingsPalette.border)
                .frame(width: 1)

            VStack(spacing: 0) {
                header

                Rectangle()
                    .fill(SettingsPalette.border)
                    .frame(height: 1)

                content
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .background(SettingsPalette.content)
        .preferredColorScheme(.dark)
        .onAppear {
            appModel.refresh()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            Spacer()
                .frame(height: 42)

            ForEach(SettingsPane.allCases) { pane in
                Button {
                    selection = pane
                    appModel.refresh()
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: pane.systemImage)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 18, height: 18)
                        Text(pane.title)
                            .font(.system(size: 14, weight: .regular))
                            .lineLimit(1)
                        Spacer()
                    }
                    .foregroundStyle(selection == pane ? .white : SettingsPalette.secondaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(selection == pane ? SettingsPalette.accent : .clear)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 150)
        .background(SettingsPalette.sidebar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(selection.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(SettingsPalette.primaryText)

            Spacer()

            switch selection {
            case .pinnedApps:
                Button {
                    appModel.refreshCatalogApps()
                    isAppPickerPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(SettingsToolbarButtonStyle())
                .help("添加应用")
                .popover(isPresented: $isAppPickerPresented) {
                    AppPickerPopover()
                        .environmentObject(appModel)
                }
            case .runningApps:
                Button {
                    appModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(SettingsToolbarButtonStyle())
                .help("刷新")
            case .privacy, .about:
                EmptyView()
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(height: 52)
        .background(SettingsPalette.header)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .pinnedApps:
            PinnedAppsPane(showAppPicker: {
                appModel.refreshCatalogApps()
            })
        case .runningApps:
            RunningAppsPane()
        case .privacy:
            PrivacySettingsPane()
        case .about:
            AboutSettingsPane()
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case pinnedApps
    case runningApps
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinnedApps:
            "常用应用"
        case .runningApps:
            "运行应用"
        case .privacy:
            "隐私"
        case .about:
            "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .pinnedApps:
            "square.grid.2x2"
        case .runningApps:
            "rectangle.stack"
        case .privacy:
            "hand.raised"
        case .about:
            "info.circle"
        }
    }
}

private struct PinnedAppsPane: View {
    @EnvironmentObject private var appModel: MacAppModel
    var showAppPicker: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 86, maximum: 96), spacing: 14, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(appModel.pinnedApps) { app in
                    PinnedAppTile(app: app)
                }

                AddPinnedAppTile(action: showAppPicker)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(SettingsPalette.panel)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SettingsPalette.content)
    }
}

private struct RunningAppsPane: View {
    @EnvironmentObject private var appModel: MacAppModel

    private let columns = [
        GridItem(.adaptive(minimum: 92, maximum: 104), spacing: 14, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(appModel.runningApps) { app in
                    RunningAppVisibilityTile(
                        app: app,
                        isHidden: appModel.isRunningAppHidden(app)
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(SettingsPalette.panel)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SettingsPalette.content)
    }
}

private struct PinnedAppTile: View {
    @EnvironmentObject private var appModel: MacAppModel
    @State private var isHovering = false

    var app: PinnedApp

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                appModel.activatePinnedApp(app)
            } label: {
                AppTileLabel(
                    name: app.displayName,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.appPath
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("打开") {
                    appModel.activatePinnedApp(app)
                }
                Button("移除", role: .destructive) {
                    appModel.removePinnedApp(app)
                }
            }

            if isHovering {
                Button(role: .destructive) {
                    appModel.removePinnedApp(app)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .offset(x: -8, y: 2)
                .help("移除")
            }
        }
        .onHover { isHovering = $0 }
    }
}

private struct RunningAppVisibilityTile: View {
    @EnvironmentObject private var appModel: MacAppModel

    var app: RunningApp
    var isHidden: Bool

    var body: some View {
        Button {
            appModel.toggleRunningAppVisibility(app)
        } label: {
            ZStack(alignment: .topTrailing) {
                AppTileLabel(
                    name: app.displayName,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: nil,
                    isActive: app.isActive,
                    isDimmed: isHidden
                )

                Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isHidden ? SettingsPalette.mutedText : SettingsPalette.accent)
                    .padding(6)
                    .background {
                        Circle()
                            .fill(SettingsPalette.panel.opacity(0.92))
                    }
                    .offset(x: -6, y: -1)
            }
        }
        .buttonStyle(.plain)
        .help(isHidden ? "已在手机端隐藏" : "将在手机端显示")
    }
}

private struct AddPinnedAppTile: View {
    @EnvironmentObject private var appModel: MacAppModel
    @State private var isPickerPresented = false
    var action: () -> Void

    var body: some View {
        Button {
            action()
            isPickerPresented = true
        } label: {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(SettingsPalette.border, lineWidth: 1)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(SettingsPalette.secondaryText)
                    }
                    .shadow(color: .black.opacity(0.24), radius: 10, y: 5)

                Text("添加")
                    .font(.system(size: 14))
                    .foregroundStyle(SettingsPalette.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 86, height: 108)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("添加应用")
        .popover(isPresented: $isPickerPresented) {
            AppPickerPopover()
                .environmentObject(appModel)
        }
    }
}

private struct AppTileLabel: View {
    var name: String
    var bundleIdentifier: String
    var appPath: String?
    var isActive = false
    var isDimmed = false

    var body: some View {
        VStack(spacing: 10) {
            MacAppIconView(
                bundleIdentifier: bundleIdentifier,
                appPath: appPath,
                isActive: isActive,
                size: 64
            )
            .opacity(isDimmed ? 0.35 : 1)
            .shadow(color: .black.opacity(isDimmed ? 0.12 : 0.35), radius: 10, y: 5)

            Text(name)
                .font(.system(size: 14))
                .foregroundStyle(isDimmed ? SettingsPalette.mutedText : SettingsPalette.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 78)
        }
        .frame(width: 86, height: 108)
        .contentShape(Rectangle())
    }
}

private struct AppPickerPopover: View {
    @EnvironmentObject private var appModel: MacAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var pinnedBundleIds: Set<String> {
        Set(appModel.pinnedApps.map(\.bundleIdentifier))
    }

    private var filteredApps: [CatalogApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return appModel.catalogApps
        }

        return appModel.catalogApps.filter { app in
            app.displayName.localizedCaseInsensitiveContains(query) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("添加常用应用")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SettingsPalette.primaryText)

                Spacer()

                Button("关闭") {
                    dismiss()
                }
            }
            .padding(18)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SettingsPalette.mutedText)
                TextField("搜索应用", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
            }
            .padding(16)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { app in
                        AppPickerRow(
                            app: app,
                            isPinned: pinnedBundleIds.contains(app.bundleIdentifier)
                        ) {
                            appModel.addPinnedApp(app)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 440, height: 500)
        .background(SettingsPalette.content)
        .onAppear {
            appModel.refreshCatalogApps()
        }
    }
}

private struct AppPickerRow: View {
    var app: CatalogApp
    var isPinned: Bool
    var add: () -> Void

    var body: some View {
        Button {
            if !isPinned {
                add()
            }
        } label: {
            HStack(spacing: 12) {
                MacAppIconView(
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.appPath,
                    size: 34
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.system(size: 14))
                        .foregroundStyle(SettingsPalette.primaryText)
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(SettingsPalette.mutedText)
                }

                Spacer()

                Image(systemName: isPinned ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isPinned ? .green : SettingsPalette.accent)
            }
            .padding(.horizontal, 10)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPinned)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.001))
        }
    }
}

private struct PrivacySettingsPane: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: appModel.permissionStatus.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(appModel.permissionStatus.accessibilityGranted ? .green : .orange)
                    .frame(width: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.permissionStatus.accessibilityGranted ? "辅助功能已授权" : "需要辅助功能权限")
                        .font(.headline)
                        .foregroundStyle(SettingsPalette.primaryText)
                    Text("用于切换应用和执行粘贴操作。")
                        .font(.callout)
                        .foregroundStyle(SettingsPalette.secondaryText)
                }

                Spacer()

                Button("打开系统设置") {
                    appModel.openAccessibilitySettings()
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(SettingsPalette.panel)
            }

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsPalette.content)
    }
}

private struct AboutSettingsPane: View {
    @EnvironmentObject private var appModel: MacAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Remote Dock")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(SettingsPalette.primaryText)

            VStack(alignment: .leading, spacing: 10) {
                SettingsInfoRow(title: "配对码", value: appModel.pairingCode)
                SettingsInfoRow(title: "连接状态", value: connectionText)
                SettingsInfoRow(title: "配对设备", value: appModel.pairedDeviceName ?? "无")
                SettingsInfoRow(title: "设备 ID", value: shortMacId)
                SettingsInfoRow(title: "常用应用", value: "\(appModel.pinnedApps.count)")
                SettingsInfoRow(title: "运行应用", value: "\(appModel.runningApps.count)")
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(SettingsPalette.panel)
            }

            Button {
                appModel.regeneratePairingCode()
            } label: {
                Label("重新生成配对码", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .help("重新生成后，iPhone 需要输入新的四位配对码。")

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsPalette.content)
    }

    private var shortMacId: String {
        String(appModel.macId.prefix(8))
    }

    private var connectionText: String {
        switch appModel.connectionState {
        case .idle:
            "空闲"
        case .discovering:
            "等待连接"
        case .connecting:
            "正在连接"
        case let .connected(peer):
            "已连接 \(peer.displayName)"
        case .reconnecting:
            "正在重连"
        case .disconnected:
            "已断开"
        case let .failed(message):
            "连接失败：\(message)"
        }
    }
}

private struct SettingsInfoRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(SettingsPalette.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(SettingsPalette.primaryText)
        }
        .font(.callout)
    }
}

private struct SettingsToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(SettingsPalette.secondaryText)
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.white.opacity(0.08) : .clear)
            }
    }
}

private enum SettingsPalette {
    static let sidebar = Color(nsColor: NSColor(calibratedRed: 0.25, green: 0.26, blue: 0.25, alpha: 1))
    static let header = Color(nsColor: NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.21, alpha: 1))
    static let content = Color(nsColor: NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.14, alpha: 1))
    static let panel = Color(nsColor: NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1))
    static let border = Color.white.opacity(0.12)
    static let accent = Color(nsColor: NSColor.systemBlue)
    static let primaryText = Color.white.opacity(0.88)
    static let secondaryText = Color.white.opacity(0.72)
    static let mutedText = Color.white.opacity(0.46)
}
