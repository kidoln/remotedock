import SwiftUI
import UIKit

struct ClipboardView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        NavigationStack {
            List(appModel.clipboard.filteredItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.plainText)
                        .font(.body)
                        .lineLimit(3)

                    HStack {
                        Text(item.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)

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
                .padding(.vertical, 6)
            }
            .navigationTitle("Clipboard")
            .searchable(text: $appModel.clipboard.searchText, placement: .navigationBarDrawer(displayMode: .always))
            .safeAreaInset(edge: .top) {
                ConnectionBanner()
            }
        }
    }
}
