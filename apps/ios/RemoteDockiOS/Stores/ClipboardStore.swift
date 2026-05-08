import Foundation
import RemoteDockCore

struct ClipboardStore: Equatable {
    var items: [ClipboardItem] = []
    var searchText = ""
    var lastPastedItemId: String?

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.plainText.localizedCaseInsensitiveContains(query)
        }
    }
}
