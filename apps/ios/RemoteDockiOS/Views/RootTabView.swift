import SwiftUI
import UIKit
import RemoteDockCore
import RemoteDockTransport

struct RootTabView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @State private var selectedTab: RemoteDockTab = .dock

    private let landscapeContentLeadingInset: CGFloat = 52
    private let landscapeTabBarLeadingOutset: CGFloat = 2
    private let portraitSwipeMinimumDistance: CGFloat = 50

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            adaptiveTabLayout(isLandscape: isLandscape)
        }
        .overlay {
            ZStack {
                // 后台重连时显示 loading 界面
                if appModel.isBackgroundReconnecting {
                    ReconnectingOverlay()
                }

                if let notice = appModel.versionMismatchNotice, appModel.isConnected {
                    VersionMismatchNoticeOverlay(
                        notice: notice,
                        language: appModel.settings.remoteLanguage,
                        onDismiss: {
                            appModel.dismissVersionMismatchNotice()
                        }
                    )
                }
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

    private func adaptiveTabLayout(isLandscape: Bool) -> some View {
        ZStack(alignment: .leading) {
            PhonePageBackground()

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, isLandscape ? landscapeContentLeadingInset : 0)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 36, coordinateSpace: .local)
                        .onEnded { value in
                            guard !isLandscape else { return }
                            selectAdjacentTab(for: value.translation)
                        }
                )

            if isLandscape {
                LandscapeSystemTabBar(selectedTab: $selectedTab)
                    .offset(x: -landscapeTabBarLeadingOutset)
                    .zIndex(1)
            }
        }
        .background(PhoneTheme.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isLandscape {
                PortraitSystemTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 9)
                    .background(Color.clear)
            }
        }
    }

    private func selectAdjacentTab(for translation: CGSize) {
        let horizontalDistance = abs(translation.width)
        guard horizontalDistance >= portraitSwipeMinimumDistance else { return }
        guard horizontalDistance > abs(translation.height) * 1.35 else { return }
        guard let currentIndex = RemoteDockTab.allCases.firstIndex(of: selectedTab) else { return }

        let targetIndex = currentIndex + (translation.width < 0 ? 1 : -1)
        guard RemoteDockTab.allCases.indices.contains(targetIndex) else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            selectedTab = RemoteDockTab.allCases[targetIndex]
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
        .frame(maxWidth: isSelected ? 64 : 50, minHeight: isSelected ? 16 : 36, maxHeight: 40)
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

private struct LandscapeSystemTabBar: View {
    @Binding var selectedTab: RemoteDockTab

    private let tabBarWidth: CGFloat = 54

    var body: some View {
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

                        Text(language.localizedString("ios.pairing.title"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.94))
                            .shadow(color: Color.black.opacity(0.32), radius: 8, x: 0, y: 2)
                            .multilineTextAlignment(.center)

                        Text(language.localizedString("ios.pairing.description"))
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
                        Label(language.localizedString("action.connect"), systemImage: "link")
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
                    .accessibilityLabel(language.localizedString("ios.pairing.title"))
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
                    .accessibilityLabel(language.localizedString("ios.pairing.fourDigitCode"))

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
            language.localizedString("ios.pairing.status.ready")
        case .discovering:
            appModel.discovery.availableMacs.isEmpty
                ? language.localizedString("ios.pairing.status.searching")
                : language.localizedString("ios.pairing.status.autoConnect")
        case .connecting:
            language.localizedString("ios.pairing.status.connecting")
        case .connected:
            language.localizedString("connection.connectedShort")
        case .reconnecting:
            language.localizedString("connection.reconnectingMac")
        case .disconnected:
            language.localizedString("ios.pairing.status.disconnected")
        case .failed:
            language.localizedString("ios.pairing.status.failed")
        }
    }

    private var language: RemoteDockLanguage {
        appModel.settings.remoteLanguage
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

/// 后台重连时显示的 loading 覆盖层
private struct ReconnectingOverlay: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @State private var rotation: Double = 0

    private let cardSize = CGSize(width: 180, height: 180)

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            ZStack {
                // 主卡片背景
                RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                    .background {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.35)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.28),
                                        PhoneTheme.tabBarStroke.opacity(0.52),
                                        Color.black.opacity(0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
                    .shadow(color: Color.black.opacity(0.36), radius: 32, x: 0, y: 16)
                    .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.22), radius: 28, x: 0, y: 0)

                VStack(spacing: 16) {
                    // 旋转的连接图标
                    ZStack {
                        // 外圈光环
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        PhoneTheme.iconWarmGlow.opacity(0.6),
                                        PhoneTheme.iconWarmGlow.opacity(0.1),
                                        PhoneTheme.iconWarmGlow.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(rotation))
                            .blur(radius: 2)

                        // 内圈背景
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        PhoneTheme.tabBarSelectedBackground.opacity(0.5),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 52, height: 52)

                        // 中心图标
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.98),
                                        PhoneTheme.accent.opacity(0.9)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.4), radius: 16, x: 0, y: 6)

                    // 文字内容区 - 固定高度
                    VStack(spacing: 6) {
                        Text(appModel.settings.remoteLanguage.localizedString("connection.reconnecting"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.94))
                            .frame(height: 20)

                        // Mac 名称 - 固定高度，没有内容时留白
                        Text(appModel.discovery.availableMacs.first?.displayName ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .frame(height: 18)
                    }
                }
                .frame(width: cardSize.width, height: cardSize.height)
            }
            .frame(width: cardSize.width, height: cardSize.height)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: rotation)
        .onAppear {
            rotation = 360
        }
        .zIndex(999)
    }
}

private struct VersionMismatchNoticeOverlay: View {
    var notice: RemoteDockVersionMismatchNotice
    var language: RemoteDockLanguage
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 18) {
                iconHeader

                VStack(spacing: 9) {
                    Text(title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.74))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                versionComparison

                // 按钮区域
                if notice.mismatch == .localNewer {
                    // Mac 版本过旧时，显示两个按钮
                    HStack(spacing: 10) {
                        Button(action: onDismiss) {
                            Text(language.localizedString("action.gotIt"))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.74))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language.localizedString("action.gotIt"))

                        Button(action: {
                            if let url = URL(string: "https://kidoln.github.io/remotedock/") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text(language.localizedString("ios.versionMismatch.downloadMacApp"))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(PhoneTheme.canvas)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.98),
                                                    PhoneTheme.accent.opacity(0.94)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.38), radius: 13, x: 0, y: 5)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language.localizedString("ios.versionMismatch.downloadMacApp"))
                    }
                } else {
                    // iPhone 版本过旧时，只显示一个按钮
                    Button(action: onDismiss) {
                        Text(language.localizedString("action.gotIt"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(PhoneTheme.canvas)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.98),
                                                PhoneTheme.accent.opacity(0.94)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.38), radius: 13, x: 0, y: 5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.localizedString("action.gotIt"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 352)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                PhoneTheme.panelBackgroundTop.opacity(0.98),
                                PhoneTheme.panelBackground.opacity(0.99)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.30)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.28),
                                        PhoneTheme.tabBarStroke.opacity(0.52),
                                        Color.black.opacity(0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
                    .shadow(color: Color.black.opacity(0.36), radius: 28, x: 0, y: 16)
                    .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.20), radius: 26, x: 0, y: 0)
            }
            .padding(.horizontal, 22)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: notice.id)
        .zIndex(998)
    }

    private var iconHeader: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            PhoneTheme.tabBarSelectedBackground.opacity(0.78),
                            Color.black.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: PhoneTheme.iconWarmGlow.opacity(0.30), radius: 18, x: 0, y: 6)

            Image(systemName: notice.mismatch == .localNewer ? "desktopcomputer" : "iphone")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            PhoneTheme.accent.opacity(0.90)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .accessibilityHidden(true)
    }

    private var versionComparison: some View {
        HStack(spacing: 10) {
            versionPill(
                label: language.localizedString("ios.versionMismatch.phoneVersion"),
                value: notice.phoneVersion,
                systemImage: "iphone"
            )

            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.48))
                .frame(width: 18)
                .accessibilityHidden(true)

            versionPill(
                label: language.localizedString("ios.versionMismatch.macVersion"),
                value: notice.macVersion,
                systemImage: "desktopcomputer"
            )
        }
    }

    private func versionPill(label: String, value: String, systemImage: String) -> some View {
        VStack(spacing: 7) {
            Label(label, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                }
        }
    }

    private var title: String {
        switch notice.mismatch {
        case .localNewer:
            language.localizedString("ios.versionMismatch.macOutdated.title")
        case .remoteNewer:
            language.localizedString("ios.versionMismatch.phoneOutdated.title")
        }
    }

    private var message: String {
        switch notice.mismatch {
        case .localNewer:
            language.localizedString("ios.versionMismatch.macOutdated.message")
        case .remoteNewer:
            language.localizedString("ios.versionMismatch.phoneOutdated.message")
        }
    }
}
