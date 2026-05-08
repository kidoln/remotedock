import RemoteDockCore
import SwiftUI

struct DockView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @State private var isClipboardDrawerExpanded = true
    @State private var didResolveClipboardDrawerDrag = false

    var body: some View {
        PhonePageSurface {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
                Group {
                    if isLandscape {
                        HStack(spacing: 0) {
                            dockContent(iconGridLayout: .landscape, iconGridMetricsSize: proxy.size)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()

                            landscapeClipboardDrawer(in: proxy.size)
                                .zIndex(2)
                        }
                    } else {
                        dockContent()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .onAppear {
                    initializeClipboardDrawerWidth(for: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    updateClipboardDrawerWidth(for: newSize)
                }
            }
        }
    }

    @ViewBuilder
    private func dockContent(
        iconGridLayout: PhoneIconGridLayout = .automatic,
        iconGridMetricsSize: CGSize? = nil
    ) -> some View {
        if appModel.dock.apps.isEmpty {
            PhoneEmptyState(title: "暂无 Dock 应用", systemImage: "dock.rectangle")
        } else {
            PhoneIconGrid(
                gridCount: appModel.settings.iconGridCount,
                layout: iconGridLayout,
                metricsSize: iconGridMetricsSize
            ) { iconSize in
                ForEach(appModel.dock.apps) { app in
                    Button {
                        appModel.activate(app)
                    } label: {
                        AppIconView(
                            title: app.displayName,
                            isActive: appModel.dock.lastActivatedAppId == app.id,
                            image: appModel.iconImage(for: app)
                        )
                        .frame(width: iconSize, height: iconSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(app.displayName)
                    .accessibilityHint("切换到 Mac 上的这个应用")
                }
            }
        }
    }

    private func landscapeClipboardDrawer(in size: CGSize) -> some View {
        let minWidth = minDrawerWidth(for: size)
        let currentWidth = clipboardDrawerWidth(for: size)

        return DockClipboardDrawer(
            items: appModel.clipboard.items,
            lastPastedItemId: appModel.clipboard.lastPastedItemId,
            fontSize: appModel.settings.clipboardFontSize,
            width: currentWidth,
            minWidth: minWidth,
            isExpanded: isClipboardDrawerExpanded,
            onPaste: { item in
                appModel.paste(item)
            },
            onToggle: {
                toggleClipboardDrawer()
            },
            onHandleDragChanged: { value in
                handleClipboardDrawerDragChanged(value)
            },
            onHandleDragEnded: { value in
                handleClipboardDrawerDragEnded(value)
            }
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: currentWidth)
    }

    private func initializeClipboardDrawerWidth(for size: CGSize) {
        guard size.width > size.height else { return }
        didResolveClipboardDrawerDrag = false
    }

    private func updateClipboardDrawerWidth(for size: CGSize) {
        didResolveClipboardDrawerDrag = false
    }

    private func toggleClipboardDrawer() {
        setClipboardDrawerExpanded(!isClipboardDrawerExpanded)
    }

    private func setClipboardDrawerExpanded(_ isExpanded: Bool) {
        guard isClipboardDrawerExpanded != isExpanded else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isClipboardDrawerExpanded = isExpanded
        }
    }

    private func handleClipboardDrawerDragChanged(_ value: DragGesture.Value) {
        guard !didResolveClipboardDrawerDrag else { return }
        guard let isExpanded = clipboardDrawerTarget(for: value.translation, minimumDistance: 8) else { return }

        didResolveClipboardDrawerDrag = true
        setClipboardDrawerExpanded(isExpanded)
    }

    private func handleClipboardDrawerDragEnded(_ value: DragGesture.Value) {
        defer {
            didResolveClipboardDrawerDrag = false
        }

        guard !didResolveClipboardDrawerDrag else { return }

        let finalTranslation = dominantTranslation(
            value.translation,
            predictedTranslation: value.predictedEndTranslation
        )
        guard let isExpanded = clipboardDrawerTarget(for: finalTranslation, minimumDistance: 6) else { return }

        setClipboardDrawerExpanded(isExpanded)
    }

    private func dominantTranslation(_ translation: CGSize, predictedTranslation: CGSize) -> CGSize {
        abs(predictedTranslation.width) > abs(translation.width) ? predictedTranslation : translation
    }

    private func clipboardDrawerTarget(for translation: CGSize, minimumDistance: CGFloat) -> Bool? {
        let horizontalDistance = abs(translation.width)
        guard horizontalDistance >= minimumDistance else { return nil }
        guard horizontalDistance > abs(translation.height) else { return nil }

        return translation.width < 0
    }

    private func clipboardDrawerWidth(for size: CGSize) -> CGFloat {
        isClipboardDrawerExpanded ? maxDrawerWidth(for: size) : minDrawerWidth(for: size)
    }

    private func maxDrawerWidth(for size: CGSize) -> CGFloat {
        floor(size.width / 2)
    }

    private func minDrawerWidth(for size: CGSize) -> CGFloat {
        min(maxDrawerWidth(for: size), 18)
    }
}

private struct DockClipboardDrawer: View {
    var items: [ClipboardItem]
    var lastPastedItemId: String?
    var fontSize: PhoneClipboardFontSize
    var width: CGFloat
    var minWidth: CGFloat
    var isExpanded: Bool
    var onPaste: (ClipboardItem) -> Void
    var onToggle: () -> Void
    var onHandleDragChanged: (DragGesture.Value) -> Void
    var onHandleDragEnded: (DragGesture.Value) -> Void

    var body: some View {
        HStack(spacing: 0) {
            handle

            if isExpanded {
                drawerContent
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(alignment: .trailing) {
            drawerBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Color.black.opacity(0.24), radius: 14, x: -5, y: 0)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private var handle: some View {
        Button(action: onToggle) {
            Capsule()
                .fill(Color.white.opacity(isExpanded ? 0.46 : 0.72))
                .frame(width: 3, height: 82)
                .frame(width: minWidth)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            DragGesture(minimumDistance: 4)
                .onChanged(onHandleDragChanged)
                .onEnded(onHandleDragEnded)
        )
        .accessibilityLabel(isExpanded ? "收起剪贴板浮层" : "展开剪贴板浮层")
        .accessibilityHint("也可以左右拖动把手")
    }

    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                DockClipboardDrawerEmptyState()
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(items) { item in
                            Button {
                                onPaste(item)
                            } label: {
                                DockClipboardDrawerItem(
                                    item: item,
                                    isLastPasted: lastPastedItemId == item.id,
                                    fontSize: fontSize
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.plainText)
                            .accessibilityHint("立即发送到 Mac")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var drawerBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.13).opacity(0.96),
                Color(red: 0.075, green: 0.083, blue: 0.098).opacity(0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DockClipboardDrawerItem: View {
    var item: ClipboardItem
    var isLastPasted: Bool
    var fontSize: PhoneClipboardFontSize

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            isLastPasted ? PhoneTheme.accent.opacity(0.20) : Color.white.opacity(0.065),
                            PhoneTheme.rowBackground.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isLastPasted ? PhoneTheme.accent.opacity(0.44) : Color.white.opacity(0.075), lineWidth: 1)
                }

            if isLastPasted {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(PhoneTheme.accent.opacity(0.9))
                    .frame(width: 3)
                    .padding(.vertical, 10)
                    .padding(.leading, 1)
            }

            Text(displayText)
                .font(fontSize.clipboardDrawerFont)
                .lineSpacing(fontSize.clipboardDrawerLineSpacing)
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: fontSize.clipboardDrawerTextMinHeight, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(height: fontSize.clipboardDrawerCardHeight)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var displayText: String {
        let trimmedText = item.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "空白文本" : trimmedText
    }
}

private extension PhoneClipboardFontSize {
    var clipboardDrawerFont: Font {
        switch self {
        case .small:
            return .footnote
        case .medium:
            return .callout
        case .large:
            return .body
        }
    }

    var clipboardDrawerLineSpacing: CGFloat {
        switch self {
        case .small:
            return 2
        case .medium:
            return 3
        case .large:
            return 3
        }
    }

    var clipboardDrawerCardHeight: CGFloat {
        switch self {
        case .small:
            return 76
        case .medium:
            return 92
        case .large:
            return 108
        }
    }

    var clipboardDrawerTextMinHeight: CGFloat {
        switch self {
        case .small:
            return 56
        case .medium:
            return 68
        case .large:
            return 84
        }
    }
}

private struct DockClipboardDrawerEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.44))

            Text("暂无剪贴板内容")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PhoneTheme.rowBackground.opacity(0.70))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}
