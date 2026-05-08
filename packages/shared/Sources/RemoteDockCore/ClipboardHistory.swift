import CryptoKit
import Foundation

public struct ClipboardHistoryPolicy: Equatable, Sendable {
    public var maxItems: Int
    public var maxTextBytes: Int
    public var excludedSourceBundleIdentifiers: Set<String>

    public init(
        maxItems: Int = 100,
        maxTextBytes: Int = 16 * 1024,
        excludedSourceBundleIdentifiers: Set<String> = []
    ) {
        self.maxItems = maxItems
        self.maxTextBytes = maxTextBytes
        self.excludedSourceBundleIdentifiers = excludedSourceBundleIdentifiers
    }
}

public enum ClipboardHistoryReducer {
    public static func normalizeText(_ text: String, maxBytes: Int) -> String {
        guard maxBytes > 0 else { return "" }
        var bytes = Array(text.utf8.prefix(maxBytes))
        while String(bytes: bytes, encoding: .utf8) == nil, !bytes.isEmpty {
            bytes.removeLast()
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    public static func contentHash(for text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func makeItem(
        text: String,
        sourceAppBundleId: String?,
        now: Date = Date(),
        policy: ClipboardHistoryPolicy = ClipboardHistoryPolicy()
    ) -> ClipboardItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let sourceAppBundleId,
           policy.excludedSourceBundleIdentifiers.contains(sourceAppBundleId) {
            return nil
        }

        let normalizedText = normalizeText(trimmed, maxBytes: policy.maxTextBytes)
        guard !normalizedText.isEmpty else { return nil }

        let hash = contentHash(for: normalizedText)
        return ClipboardItem(
            id: hash,
            plainText: normalizedText,
            sourceAppBundleId: sourceAppBundleId,
            createdAt: now,
            contentHash: hash
        )
    }

    public static func inserting(
        _ item: ClipboardItem,
        into history: [ClipboardItem],
        policy: ClipboardHistoryPolicy = ClipboardHistoryPolicy()
    ) -> [ClipboardItem] {
        var next = history.filter { $0.contentHash != item.contentHash }
        next.insert(item, at: 0)
        return Array(next.prefix(max(policy.maxItems, 0)))
    }
}
