import SwiftUI
import RemoteDockTransport

struct RootTabView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @State private var selectedTab: RemoteDockTab = .dock

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                LandscapeTabLayout(selectedTab: $selectedTab) {
                    selectedContent
                }
            } else {
                portraitTabs
            }
        }
        .fullScreenCover(isPresented: pairingGateBinding) {
            PairingCodeGateView()
                .environmentObject(appModel)
        }
    }

    private var pairingGateBinding: Binding<Bool> {
        Binding {
            appModel.shouldShowPairingGate
        } set: { _ in }
    }

    private var portraitTabs: some View {
        TabView(selection: $selectedTab) {
            DockView()
                .tabItem {
                    Label(RemoteDockTab.dock.title, systemImage: RemoteDockTab.dock.systemImage)
                }
                .tag(RemoteDockTab.dock)

            RunningAppsView()
                .tabItem {
                    Label(RemoteDockTab.running.title, systemImage: RemoteDockTab.running.systemImage)
                }
                .tag(RemoteDockTab.running)

            ClipboardView()
                .tabItem {
                    Label(RemoteDockTab.clipboard.title, systemImage: RemoteDockTab.clipboard.systemImage)
                }
                .tag(RemoteDockTab.clipboard)

            SettingsView()
                .tabItem {
                    Label(RemoteDockTab.settings.title, systemImage: RemoteDockTab.settings.systemImage)
                }
                .tag(RemoteDockTab.settings)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .dock:
            DockView()
        case .running:
            RunningAppsView()
        case .clipboard:
            ClipboardView()
        case .settings:
            SettingsView()
        }
    }
}

private enum RemoteDockTab: CaseIterable, Hashable {
    case dock
    case running
    case clipboard
    case settings

    var title: String {
        switch self {
        case .dock:
            "Dock"
        case .running:
            "Running"
        case .clipboard:
            "Clipboard"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dock:
            "dock.rectangle"
        case .running:
            "rectangle.stack"
        case .clipboard:
            "doc.on.clipboard"
        case .settings:
            "gearshape"
        }
    }
}

private struct LandscapeTabLayout<Content: View>: View {
    @Binding var selectedTab: RemoteDockTab
    @ViewBuilder var content: () -> Content

    private let tabBarWidth: CGFloat = 58

    var body: some View {
        ZStack(alignment: .leading) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, tabBarWidth)

            tabBar
                .zIndex(1)
        }
        .background(PhoneTheme.canvas)
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                ForEach(RemoteDockTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.48))
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedTab == tab ? PhoneTheme.accent.opacity(0.26) : Color.clear)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: tabBarWidth)
        .frame(maxHeight: .infinity)
        .background(PhoneTheme.bannerBackground)
    }
}

private struct PairingCodeGateView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @FocusState private var isPairingCodeFocused: Bool

    private let digitCount = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "macbook.and.iphone")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.tint)

                    Text("输入四位数字")
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text("请查看 Mac 上显示的配对码。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                pairingCodeInput
                    .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Label(statusText, systemImage: statusSymbol)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(statusColor)
                        .multilineTextAlignment(.center)

                    if let message = appModel.connectionErrorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(minHeight: 48)

                Button {
                    appModel.connectToPreferredMacIfPossible(manuallyTriggered: true)
                } label: {
                    Label("连接", systemImage: "link")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canTapConnectButton)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 72)
            .padding(.bottom, 24)
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPairingCodeFocused = true
                    } label: {
                        Image(systemName: "keyboard")
                    }
                    .accessibilityLabel("输入配对码")
                }
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            isPairingCodeFocused = true
            appModel.connectToPreferredMacIfPossible()
        }
        .onChange(of: appModel.settings.pairingCodeInput) {
            appModel.connectToPreferredMacIfPossible()
        }
        .onChange(of: appModel.discovery.availableMacs) {
            appModel.connectToPreferredMacIfPossible()
        }
    }

    private var pairingCodeInput: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 12
            let availableWidth = proxy.size.width
            let boxWidth = min(64, max(50, (availableWidth - spacing * CGFloat(digitCount - 1)) / CGFloat(digitCount)))
            let boxHeight = boxWidth * 1.28

            ZStack {
                TextField("", text: pairingCodeBinding)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isPairingCodeFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityLabel("四位配对码")

                HStack(spacing: spacing) {
                    ForEach(0..<digitCount, id: \.self) { index in
                        DigitBox(
                            value: digit(at: index),
                            isActive: activeDigitIndex == index,
                            size: CGSize(width: boxWidth, height: boxHeight)
                        )
                    }
                }
                .frame(height: boxHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    isPairingCodeFocused = true
                }
            }
            .frame(width: proxy.size.width, height: boxHeight)
        }
        .frame(height: 82)
    }

    private var pairingCodeBinding: Binding<String> {
        Binding {
            appModel.settings.pairingCodeInput
        } set: { value in
            appModel.updatePairingCodeInput(value)
        }
    }

    private var digits: [String] {
        Array(appModel.settings.pairingCodeInput).map(String.init)
    }

    private var activeDigitIndex: Int {
        min(digits.count, digitCount - 1)
    }

    private var statusText: String {
        switch appModel.discovery.connectionState {
        case .idle:
            "准备搜索 Mac"
        case .discovering:
            appModel.discovery.availableMacs.isEmpty ? "正在搜索附近的 Mac" : "输入完成后自动连接"
        case .connecting:
            "正在连接 Mac"
        case .connected:
            "已连接"
        case .reconnecting:
            "正在重连 Mac"
        case .disconnected:
            "连接已断开，请重新输入"
        case .failed:
            "连接失败，请检查配对码"
        }
    }

    private var statusSymbol: String {
        switch appModel.discovery.connectionState {
        case .connecting, .reconnecting:
            "arrow.triangle.2.circlepath"
        case .failed:
            "exclamationmark.triangle.fill"
        case .connected:
            "checkmark.circle.fill"
        default:
            "antenna.radiowaves.left.and.right"
        }
    }

    private var statusColor: Color {
        switch appModel.discovery.connectionState {
        case .failed:
            .orange
        case .connected:
            .green
        default:
            .secondary
        }
    }

    private var canTapConnectButton: Bool {
        guard appModel.settings.pairingCodeInput.count == digitCount else {
            return false
        }

        switch appModel.discovery.connectionState {
        case .connecting, .connected, .reconnecting:
            return false
        default:
            return true
        }
    }

    private func digit(at index: Int) -> String? {
        guard digits.indices.contains(index) else {
            return nil
        }

        return digits[index]
    }
}

private struct DigitBox: View {
    var value: String?
    var isActive: Bool
    var size: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isActive ? Color.accentColor : Color(.separator), lineWidth: isActive ? 2 : 1)

            Text(value ?? "")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size.width, height: size.height)
    }
}
