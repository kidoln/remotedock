import SwiftUI
import UIKit
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
        ZStack {
            PhonePageBackground()

            TabView(selection: $selectedTab) {
                DockView()
                    .tag(RemoteDockTab.dock)

                RunningAppsView()
                    .tag(RemoteDockTab.running)

                ClipboardView()
                    .tag(RemoteDockTab.clipboard)

                SettingsView()
                    .tag(RemoteDockTab.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PortraitSystemTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 9)
                .background(Color.clear)
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

private struct PortraitSystemTabBar: View {
    @Binding var selectedTab: RemoteDockTab

    var body: some View {
        HStack(spacing: 7) {
            ForEach(RemoteDockTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    PortraitTabBarItem(tab: tab, isSelected: selectedTab == tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(7)
        .frame(height: 54)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.13),
                            PhoneTheme.tabBarBackground.opacity(0.88),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.32)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    PhoneTheme.tabBarStroke.opacity(0.58),
                                    Color.black.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 13)
                .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.18), radius: 20, x: 0, y: 0)
        }
    }
}

private struct PortraitTabBarItem: View {
    var tab: RemoteDockTab
    var isSelected: Bool

    var body: some View {
        HStack(spacing: isSelected ? 7 : 0) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 16, weight: .bold))
                .symbolVariant(isSelected ? .fill : .none)
                .frame(width: 18, height: 18)

            if isSelected {
                Text(tab.shortTitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
            }
        }
        .foregroundStyle(isSelected ? Color.white.opacity(0.98) : Color.white.opacity(0.68))
        .frame(maxWidth: isSelected ? 64 : 50, minHeight: isSelected ? 26 : 36, maxHeight: 40)
        .padding(.horizontal, isSelected ? 0 : 0)
        .padding(.vertical, isSelected ? 3 : 0)
        .background {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                PhoneTheme.tabBarSelectedBackground.opacity(0.95),
                                Color.black.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.34), radius: 12, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 5)
            }
        }
        .contentShape(Capsule(style: .continuous))
    }
}

private struct LandscapeTabLayout<Content: View>: View {
    @Binding var selectedTab: RemoteDockTab
    @ViewBuilder var content: () -> Content

    private let tabBarWidth: CGFloat = 54
    private let contentLeadingInset: CGFloat = 52
    private let leadingOutset: CGFloat = 2

    var body: some View {
        ZStack(alignment: .leading) {
            PhonePageBackground()

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, contentLeadingInset)

            tabBar
                .offset(x: -leadingOutset)
                .zIndex(1)
        }
        .background(PhoneTheme.canvas)
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 7) {
                ForEach(RemoteDockTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedTab = tab
                        }
                    } label: {
                        LandscapeTabBarItem(tab: tab, isSelected: selectedTab == tab)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(7)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.13),
                                PhoneTheme.tabBarBackground.opacity(0.88),
                                Color.black.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.32)
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.24),
                                        PhoneTheme.tabBarStroke.opacity(0.58),
                                        Color.black.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 13)
                    .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.18), radius: 20, x: 0, y: 0)
            }

            Spacer(minLength: 0)
        }
        .frame(width: tabBarWidth)
        .frame(maxHeight: .infinity)
        .background(Color.clear)
    }

    private struct LandscapeTabBarItem: View {
        var tab: RemoteDockTab
        var isSelected: Bool

        var body: some View {
            VStack(spacing: isSelected ? 4 : 0) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .symbolVariant(isSelected ? .fill : .none)
                    .frame(width: 20, height: 20)

                if isSelected {
                    Text(tab.shortTitle)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                }
            }
            .foregroundStyle(isSelected ? Color.white.opacity(0.98) : Color.white.opacity(0.68))
            .frame(maxWidth: 50, minHeight: isSelected ? 52 : 40, maxHeight: 52)
            .padding(.vertical, isSelected ? 6 : 0)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    PhoneTheme.tabBarSelectedBackground.opacity(0.95),
                                    Color.black.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        }
                        .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.34), radius: 12, x: 0, y: 0)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 5)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
    }
}

private extension RemoteDockTab {
    var shortTitle: String {
        switch self {
        case .dock:
            "Dock"
        case .running:
            "Run"
        case .clipboard:
            "Clip"
        case .settings:
            "Set"
        }
    }
}

private struct PairingCodeGateView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @FocusState private var isPairingCodeFocused: Bool

    private let digitCount = 4

    var body: some View {
        NavigationStack {
            ZStack {
                PhonePageBackground()

                VStack(spacing: 28) {
                    VStack(spacing: 14) {
                        Image(systemName: "macbook.and.iphone")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 2)

                        Text("输入配对码")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.94))
                            .shadow(color: Color.black.opacity(0.32), radius: 8, x: 0, y: 2)
                            .multilineTextAlignment(.center)

                        Text("本应用需要配合 Mac 版本的应用配对使用，请查看 Mac 上显示的配对码")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineSpacing(7.5)
                            .frame(maxWidth: 280)
                    }
                    .padding(.top, 48)

                    PhonePageSurface {
                        pairingCodeInput
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 10) {
                        Label(statusText, systemImage: statusSymbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .multilineTextAlignment(.center)

                        if let message = appModel.connectionErrorMessage {
                            Text(message)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.86))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 24)

                    Button {
                        appModel.connectToPreferredMacIfPossible(manuallyTriggered: true)
                    } label: {
                        Label("连接", systemImage: "link")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(PhoneTheme.canvas)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.98),
                                                PhoneTheme.accent.opacity(0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.44), radius: 12, x: 0, y: 4)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTapConnectButton)
                    .opacity(canTapConnectButton ? 1 : 0.52)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPairingCodeFocused = true
                    } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.86))
                    }
                    .accessibilityLabel("输入配对码")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(PhoneTheme.accent)
        .interactiveDismissDisabled()
        .onAppear {
            InterfaceOrientationLock.lockToPortrait()
            isPairingCodeFocused = true
            appModel.connectToPreferredMacIfPossible()
        }
        .onDisappear {
            InterfaceOrientationLock.unlock()
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
            let spacing: CGFloat = 14
            let availableWidth = proxy.size.width
            let boxWidth = min(68, max(54, (availableWidth - spacing * CGFloat(digitCount - 1)) / CGFloat(digitCount)))
            let boxHeight = boxWidth * 1.32

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
        .frame(height: 90)
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
            Color(red: 1.00, green: 0.58, blue: 0.44)
        case .connected:
            Color(red: 0.40, green: 1.00, blue: 0.66)
        default:
            Color.white.opacity(0.68)
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PhoneTheme.panelBackgroundTop.opacity(0.96),
                            PhoneTheme.panelBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isActive ? [
                            PhoneTheme.accent.opacity(0.98),
                            PhoneTheme.iconWarmGlow.opacity(0.82)
                        ] : [
                            Color.white.opacity(0.22),
                            PhoneTheme.tabBarStroke.opacity(0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isActive ? 2.2 : 1.2
                )

            Text(value ?? "")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            PhoneTheme.accent.opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: isActive ? PhoneTheme.iconWarmGlow.opacity(0.34) : Color.black.opacity(0.16), radius: isActive ? 12 : 8, x: 0, y: isActive ? 4 : 3)
    }
}
