import RemoteDockCore
import SwiftUI
import UIKit

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
            sourceAppIconImage: { item in
                appModel.sourceAppIconImage(for: item)
            },
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
    var sourceAppIconImage: (ClipboardItem) -> UIImage?
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
                                    fontSize: fontSize,
                                    sourceAppIconImage: sourceAppIconImage(item)
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
        Color.clear
    }
}

private struct DockClipboardDrawerItem: View {
    var item: ClipboardItem
    var isLastPasted: Bool
    var fontSize: PhoneClipboardFontSize
    var sourceAppIconImage: UIImage?

    var body: some View {
        ZStack(alignment: .leading) {
            cardBackground

            if isLastPasted {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(PhoneTheme.accent.opacity(0.88))
                    .frame(width: 3, height: fontSize.clipboardDrawerAccentHeight)
                    .padding(.leading, 1)
            }

            HStack(alignment: .center, spacing: 12) {
                ClipboardSourceAppIconView(image: sourceAppIconImage, size: fontSize.clipboardDrawerSourceIconSize)

                Text(displayText)
                    .font(fontSize.clipboardDrawerFont)
                    .lineSpacing(fontSize.clipboardDrawerLineSpacing)
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: fontSize.clipboardDrawerTextHeight,
                        maxHeight: fontSize.clipboardDrawerTextHeight,
                        alignment: .topLeading
                    )
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
        }
        .frame(height: fontSize.clipboardDrawerCardHeight)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 5)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isLastPasted ? PhoneTheme.panelBackgroundTop.opacity(0.88) : PhoneTheme.panelBackgroundTop.opacity(0.80),
                        isLastPasted ? PhoneTheme.rowBackground.opacity(0.88) : PhoneTheme.panelBackground.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isLastPasted ? PhoneTheme.accent.opacity(0.52) : Color.white.opacity(0.15), lineWidth: 1)
            }
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
            return .callout
        case .medium:
            return .body
        case .large:
            return .title3
        }
    }

    var clipboardDrawerLineSpacing: CGFloat {
        switch self {
        case .small:
            return 3
        case .medium:
            return 3
        case .large:
            return 4
        }
    }

    var clipboardDrawerCardHeight: CGFloat {
        switch self {
        case .small:
            return 68
        case .medium:
            return 82
        case .large:
            return 96
        }
    }

    var clipboardDrawerTextHeight: CGFloat {
        switch self {
        case .small:
            return 40
        case .medium:
            return 54
        case .large:
            return 66
        }
    }

    var clipboardDrawerAccentHeight: CGFloat {
        switch self {
        case .small:
            return 32
        case .medium:
            return 46
        case .large:
            return 58
        }
    }

    var clipboardDrawerSourceIconSize: CGFloat {
        switch self {
        case .small:
            return 34
        case .medium:
            return 40
        case .large:
            return 46
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PhoneTheme.panelBackground.opacity(0.82))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}
