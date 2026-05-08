import RemoteDockCore
import SwiftUI

struct DockView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @State private var clipboardDrawerWidth: CGFloat?
    @State private var dragStartDrawerWidth: CGFloat = 0

    var body: some View {
        PhonePageSurface {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
                let drawerWidth = isLandscape ? clampedDrawerWidth(clipboardDrawerWidth ?? maxDrawerWidth(for: proxy.size), in: proxy.size) : 0
                let drawerOutset = isLandscape ? clipboardDrawerTrailingOutset(for: proxy, drawerWidth: drawerWidth) : 0

                ZStack(alignment: .trailing) {
                    dockContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isLandscape {
                        landscapeClipboardDrawer(in: proxy.size, trailingOutset: drawerOutset)
                            .zIndex(2)
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
    private var dockContent: some View {
        if appModel.dock.apps.isEmpty {
            PhoneEmptyState(title: "暂无 Dock 应用", systemImage: "dock.rectangle")
        } else {
            PhoneIconGrid(gridCount: appModel.settings.iconGridCount) { iconSize in
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

    private func landscapeClipboardDrawer(in size: CGSize, trailingOutset: CGFloat) -> some View {
        let maxWidth = maxDrawerWidth(for: size)
        let minWidth = minDrawerWidth(for: size)
        let currentWidth = clampedDrawerWidth(clipboardDrawerWidth ?? maxWidth, in: size)

        return DockClipboardDrawer(
            items: appModel.clipboard.items,
            lastPastedItemId: appModel.clipboard.lastPastedItemId,
            width: currentWidth,
            minWidth: minWidth,
            onPaste: { item in
                appModel.paste(item)
            },
            onToggle: {
                toggleClipboardDrawer(in: size)
            },
            onHandleDragChanged: { value in
                if dragStartDrawerWidth == 0 {
                    dragStartDrawerWidth = currentWidth
                }
                let proposedWidth = dragStartDrawerWidth - value.translation.width
                clipboardDrawerWidth = clampedDrawerWidth(proposedWidth, in: size)
            },
            onHandleDragEnded: { value in
                let predictedWidth = dragStartDrawerWidth - value.predictedEndTranslation.width
                let midpoint = (minWidth + maxWidth) / 2
                let targetWidth = predictedWidth >= midpoint ? maxWidth : minWidth
                dragStartDrawerWidth = 0
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    clipboardDrawerWidth = targetWidth
                }
            }
        )
        .offset(x: trailingOutset)
        .ignoresSafeArea(.container, edges: .trailing)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: currentWidth)
    }

    private func initializeClipboardDrawerWidth(for size: CGSize) {
        guard size.width > size.height, clipboardDrawerWidth == nil else {
            return
        }
        clipboardDrawerWidth = maxDrawerWidth(for: size)
    }

    private func updateClipboardDrawerWidth(for size: CGSize) {
        guard size.width > size.height else {
            dragStartDrawerWidth = 0
            return
        }

        clipboardDrawerWidth = clampedDrawerWidth(clipboardDrawerWidth ?? maxDrawerWidth(for: size), in: size)
    }

    private func toggleClipboardDrawer(in size: CGSize) {
        let minWidth = minDrawerWidth(for: size)
        let maxWidth = maxDrawerWidth(for: size)
        let currentWidth = clampedDrawerWidth(clipboardDrawerWidth ?? maxWidth, in: size)
        let targetWidth = currentWidth > (minWidth + maxWidth) / 2 ? minWidth : maxWidth

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            clipboardDrawerWidth = targetWidth
        }
    }

    private func clampedDrawerWidth(_ width: CGFloat, in size: CGSize) -> CGFloat {
        min(max(width, minDrawerWidth(for: size)), maxDrawerWidth(for: size))
    }

    private func maxDrawerWidth(for size: CGSize) -> CGFloat {
        floor(size.width / 2)
    }

    private func minDrawerWidth(for size: CGSize) -> CGFloat {
        min(maxDrawerWidth(for: size), 18)
    }

    private func clipboardDrawerTrailingOutset(for proxy: GeometryProxy, drawerWidth: CGFloat) -> CGFloat {
        let desiredOutset = min(24, max(12, proxy.safeAreaInsets.trailing * 0.5))
        return min(desiredOutset, max(0, drawerWidth - minDrawerWidth(for: proxy.size)))
    }
}

private struct DockClipboardDrawer: View {
    var items: [ClipboardItem]
    var lastPastedItemId: String?
    var width: CGFloat
    var minWidth: CGFloat
    var onPaste: (ClipboardItem) -> Void
    var onToggle: () -> Void
    var onHandleDragChanged: (DragGesture.Value) -> Void
    var onHandleDragEnded: (DragGesture.Value) -> Void

    private var isExpanded: Bool {
        width > minWidth + 16
    }

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
                                    isLastPasted: lastPastedItemId == item.id
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
                .font(.footnote)
                .lineSpacing(2)
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(height: 76)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var displayText: String {
        let trimmedText = item.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "空白文本" : trimmedText
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
