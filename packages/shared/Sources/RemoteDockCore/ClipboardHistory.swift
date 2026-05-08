import CryptoKit
import Foundation

public struct ClipboardHistoryPolicy: Equatable, Sendable {
    public var maxItems: Int
    public var maxTextBytes: Int
    public var maxRepresentationBytes: Int
    public var excludedSourceBundleIdentifiers: Set<String>

    public init(
        maxItems: Int = 100,
        maxTextBytes: Int = 16 * 1024,
        maxRepresentationBytes: Int = 512 * 1024,
        excludedSourceBundleIdentifiers: Set<String> = []
    ) {
        self.maxItems = maxItems
        self.maxTextBytes = maxTextBytes
        self.maxRepresentationBytes = maxRepresentationBytes
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

    public static func contentHash(
        for text: String,
        richRepresentations: [ClipboardRepresentation]
    ) -> String {
        var data = Data(text.utf8)
        for representation in richRepresentations.sorted(by: { $0.kind.rawValue < $1.kind.rawValue }) {
            data.append(Data(representation.kind.rawValue.utf8))
            data.append(representation.data)
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func normalizedRepresentations(
        _ representations: [ClipboardRepresentation],
        maxBytes: Int
    ) -> [ClipboardRepresentation] {
        guard maxBytes > 0 else { return [] }

        var seenKinds = Set<ClipboardRepresentationKind>()
        var remainingBytes = maxBytes
        var normalized: [ClipboardRepresentation] = []

        for representation in representations where !representation.data.isEmpty {
            guard !seenKinds.contains(representation.kind), remainingBytes > 0 else {
                continue
            }

            guard representation.data.count <= remainingBytes else {
                continue
            }

            seenKinds.insert(representation.kind)
            normalized.append(representation)
            remainingBytes -= representation.data.count
        }

        return normalized
    }

    public static func makeItem(
        text: String,
        richRepresentations: [ClipboardRepresentation] = [],
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

        let normalizedRichRepresentations = normalizedRepresentations(
            richRepresentations,
            maxBytes: policy.maxRepresentationBytes
        )
        let hash = contentHash(for: normalizedText, richRepresentations: normalizedRichRepresentations)
        return ClipboardItem(
            id: hash,
            plainText: normalizedText,
            richRepresentations: normalizedRichRepresentations,
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
