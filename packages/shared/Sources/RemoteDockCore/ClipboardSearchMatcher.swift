import Foundation

public enum ClipboardSearchMatcher {
    public static func matches(_ item: ClipboardItem, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        return matches(item.displayText, query: query) ||
            matches(item.plainText, query: query) ||
            item.sourceAppBundleId.map { matches($0, query: query) } == true
    }

    public static func matches(_ text: String, query: String) -> Bool {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let condensedQuery = condensed(normalizedQuery)
        let keys = searchKeys(for: text)
        return keys.contains { key in
            key.contains(normalizedQuery) ||
                (!condensedQuery.isEmpty && condensed(key).contains(condensedQuery))
        }
    }

    private static func searchKeys(for text: String) -> [String] {
        let normalizedText = normalized(text)
        let pinyin = text
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripCombiningMarks, reverse: false)
            .map(normalized)

        var keys = [normalizedText]

        if let pinyin, pinyin != normalizedText {
            keys.append(pinyin)
            keys.append(initials(from: pinyin))
        }

        return keys
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    private static func condensed(_ text: String) -> String {
        String(text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func initials(from text: String) -> String {
        text
            .split { scalar in
                scalar.unicodeScalars.allSatisfy { !CharacterSet.alphanumerics.contains($0) }
            }
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }
}
