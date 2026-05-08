import Foundation
import RemoteDockCore
import UIKit

struct ClipboardStore: Equatable {
    var items: [ClipboardItem] = []
    var searchText = ""
    var lastPastedItemId: String?
    var sourceAppIconImagesByHash: [String: UIImage] = [:]

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.plainText.localizedCaseInsensitiveContains(query)
        }
    }

    static func == (lhs: ClipboardStore, rhs: ClipboardStore) -> Bool {
        lhs.items == rhs.items &&
            lhs.searchText == rhs.searchText &&
            lhs.lastPastedItemId == rhs.lastPastedItemId &&
            Set(lhs.sourceAppIconImagesByHash.keys) == Set(rhs.sourceAppIconImagesByHash.keys)
    }
}
