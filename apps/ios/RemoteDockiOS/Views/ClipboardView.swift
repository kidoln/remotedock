import RemoteDockCore
import SwiftUI
import UIKit

struct ClipboardView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        PhonePageSurface {
            VStack(spacing: 16) {
                if !appModel.clipboard.items.isEmpty {
                    searchField
                }

                clipboardContent
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSearchFocused ? PhoneTheme.accent.opacity(0.9) : Color.white.opacity(0.46))

            TextField("搜索剪贴板", text: $appModel.clipboard.searchText)
                .focused($isSearchFocused)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.92))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !appModel.clipboard.searchText.isEmpty {
                Button {
                    appModel.clipboard.searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.38))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .frame(height: 50)
        .padding(.horizontal, 14)
        .background {
            LinearGradient(
                colors: [
                    PhoneTheme.panelBackgroundTop.opacity(isSearchFocused ? 0.85 : 0.75),
                    PhoneTheme.panelBackground.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSearchFocused ? PhoneTheme.accent.opacity(0.56) : Color.white.opacity(0.16),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    @ViewBuilder
    private var clipboardContent: some View {
        let items = appModel.clipboard.filteredItems
        let hasClipboardItems = !appModel.clipboard.items.isEmpty
        let hasSearchText = hasClipboardItems && !appModel.clipboard.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if items.isEmpty {
            ClipboardEmptyState(hasSearchText: hasSearchText)
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(items) { item in
                        Button {
                            appModel.paste(item)
                        } label: {
                            ClipboardItemCard(
                                item: item,
                                isLastPasted: appModel.clipboard.lastPastedItemId == item.id,
                                fontSize: appModel.settings.clipboardFontSize,
                                sourceAppIconImage: appModel.sourceAppIconImage(for: item)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.plainText)
                        .accessibilityHint("立即发送到 Mac")
                    }
                }
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct ClipboardItemCard: View {
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
                    .frame(width: 3, height: fontSize.clipboardListAccentHeight)
                    .padding(.leading, 1)
            }

            HStack(alignment: .center, spacing: 12) {
                ClipboardSourceAppIconView(image: sourceAppIconImage, size: fontSize.clipboardListSourceIconSize)

                Text(displayText)
                    .font(fontSize.clipboardListFont)
                    .lineSpacing(fontSize.clipboardListLineSpacing)
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: fontSize.clipboardListTextHeight,
                        maxHeight: fontSize.clipboardListTextHeight,
                        alignment: .topLeading
                    )
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
        }
        .frame(height: fontSize.clipboardListCardHeight)
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

struct ClipboardSourceAppIconView: View {
    var image: UIImage?
    var size: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(1)
            } else {
                RoundedRectangle(cornerRadius: max(7, size * 0.22), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.11),
                                Color.white.opacity(0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "app.dashed")
                            .font(.system(size: max(14, size * 0.42), weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.36))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: max(7, size * 0.22), style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private extension PhoneClipboardFontSize {
    var clipboardListFont: Font {
        switch self {
        case .small:
            return .callout
        case .medium:
            return .body
        case .large:
            return .title3
        }
    }

    var clipboardListLineSpacing: CGFloat {
        switch self {
        case .small:
            return 3
        case .medium:
            return 3
        case .large:
            return 4
        }
    }

    var clipboardListCardHeight: CGFloat {
        switch self {
        case .small:
            return 68
        case .medium:
            return 82
        case .large:
            return 96
        }
    }

    var clipboardListTextHeight: CGFloat {
        switch self {
        case .small:
            return 40
        case .medium:
            return 54
        case .large:
            return 66
        }
    }

    var clipboardListAccentHeight: CGFloat {
        switch self {
        case .small:
            return 32
        case .medium:
            return 46
        case .large:
            return 58
        }
    }

    var clipboardListSourceIconSize: CGFloat {
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

private struct ClipboardEmptyState: View {
    var hasSearchText: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: hasSearchText ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.48))

            Text(hasSearchText ? "没有匹配内容" : "暂无剪贴板内容")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
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
