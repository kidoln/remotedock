import SwiftUI
import UIKit

struct ClipboardView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        NavigationStack {
            PhonePageSurface {
                List(appModel.clipboard.filteredItems) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.plainText)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(3)

                        HStack {
                            Text(item.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.52))

                            Spacer()

                            if appModel.clipboard.lastPastedItemId == item.id {
                                Label("已发送", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            Button {
                                UIPasteboard.general.string = item.plainText
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)

                            Button {
                                appModel.paste(item)
                            } label: {
                                Image(systemName: "paperplane")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(PhoneTheme.rowBackground)
                    .listRowSeparatorTint(PhoneTheme.rowSeparator)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .navigationTitle("Clipboard")
            .searchable(text: $appModel.clipboard.searchText, placement: .navigationBarDrawer(displayMode: .always))
            .safeAreaInset(edge: .top) {
                ConnectionBanner()
            }
        }
    }
}
