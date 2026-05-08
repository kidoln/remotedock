import RemoteDockCore
import SwiftUI

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
                    Color.white.opacity(isSearchFocused ? 0.075 : 0.055),
                    PhoneTheme.rowBackground.opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSearchFocused ? PhoneTheme.accent.opacity(0.42) : Color.white.opacity(0.06),
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
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        Button {
                            appModel.paste(item)
                        } label: {
                            ClipboardItemCard(
                                item: item,
                                isLastPasted: appModel.clipboard.lastPastedItemId == item.id
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

    var body: some View {
        ZStack(alignment: .leading) {
            cardBackground

            if isLastPasted {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(PhoneTheme.accent.opacity(0.88))
                    .frame(width: 3, height: 54)
                    .padding(.leading, 1)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(displayText)
                    .font(.callout)
                    .lineSpacing(3)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 61, maxHeight: 61, alignment: .topLeading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 90)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 5)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isLastPasted ? PhoneTheme.accent.opacity(0.2) : Color.white.opacity(0.055),
                        isLastPasted ? PhoneTheme.rowBackground.opacity(0.98) : PhoneTheme.rowBackground.opacity(0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.055))
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isLastPasted ? PhoneTheme.accent.opacity(0.44) : Color.white.opacity(0.07), lineWidth: 1)
            }
    }

    private var displayText: String {
        let trimmedText = item.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "空白文本" : trimmedText
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PhoneTheme.rowBackground.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.055), lineWidth: 1)
        }
    }
}
