import Foundation

public struct PinnedApp: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var bundleIdentifier: String
    public var displayName: String
    public var appPath: String
    public var iconAssetHash: String?
    public var sortOrder: Int

    public init(
        id: String,
        bundleIdentifier: String,
        displayName: String,
        appPath: String,
        iconAssetHash: String? = nil,
        sortOrder: Int
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.appPath = appPath
        self.iconAssetHash = iconAssetHash
        self.sortOrder = sortOrder
    }
}

public struct RunningApp: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var bundleIdentifier: String
    public var displayName: String
    public var pid: Int32
    public var isActive: Bool
    public var launchedAt: Date?
    public var iconAssetHash: String?

    public init(
        id: String,
        bundleIdentifier: String,
        displayName: String,
        pid: Int32,
        isActive: Bool,
        launchedAt: Date?,
        iconAssetHash: String? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.pid = pid
        self.isActive = isActive
        self.launchedAt = launchedAt
        self.iconAssetHash = iconAssetHash
    }
}

public enum ClipboardContentType: String, Codable, Equatable, Sendable {
    case text
}

public struct ClipboardRepresentationKind: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public static let rtf = ClipboardRepresentationKind(rawValue: "rtf")
    public static let rtfd = ClipboardRepresentationKind(rawValue: "rtfd")
    public static let html = ClipboardRepresentationKind(rawValue: "html")

    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(pasteboardTypeIdentifier: String) {
        self.init(rawValue: Self.normalizedRawValue(for: pasteboardTypeIdentifier))
    }

    private static func normalizedRawValue(for identifier: String) -> String {
        switch identifier.lowercased() {
        case "rtf",
             "public.rtf",
             "nsrtfpboardtype",
             "next rich text format v1.0 pasteboard type":
            "rtf"
        case "rtfd",
             "com.apple.flat-rtfd",
             "com.apple.rtfd",
             "nsrtfdpboardtype":
            "rtfd"
        case "html",
             "public.html",
             "nshtmlpboardtype",
             "apple html pasteboard type":
            "html"
        default:
            identifier
        }
    }

    public var pasteboardTypeIdentifier: String {
        switch self {
        case .rtf:
            "public.rtf"
        case .rtfd:
            "com.apple.flat-rtfd"
        case .html:
            "public.html"
        default:
            rawValue
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        self.init(rawValue: Self.normalizedRawValue(for: identifier))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ClipboardRepresentation: Codable, Equatable, Sendable {
    public var kind: ClipboardRepresentationKind
    public var data: Data

    public init(kind: ClipboardRepresentationKind, data: Data) {
        self.kind = kind
        self.data = data
    }
}

public struct ClipboardItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var contentType: ClipboardContentType
    public var plainText: String
    public var richRepresentations: [ClipboardRepresentation]
    public var sourceAppBundleId: String?
    public var createdAt: Date
    public var contentHash: String

    public init(
        id: String,
        contentType: ClipboardContentType = .text,
        plainText: String,
        richRepresentations: [ClipboardRepresentation] = [],
        sourceAppBundleId: String? = nil,
        createdAt: Date,
        contentHash: String
    ) {
        self.id = id
        self.contentType = contentType
        self.plainText = plainText
        self.richRepresentations = richRepresentations
        self.sourceAppBundleId = sourceAppBundleId
        self.createdAt = createdAt
        self.contentHash = contentHash
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contentType
        case plainText
        case richRepresentations
        case sourceAppBundleId
        case createdAt
        case contentHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contentType = try container.decode(ClipboardContentType.self, forKey: .contentType)
        plainText = try container.decode(String.self, forKey: .plainText)
        richRepresentations = try container.decodeIfPresent(
            [ClipboardRepresentation].self,
            forKey: .richRepresentations
        ) ?? []
        sourceAppBundleId = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        contentHash = try container.decode(String.self, forKey: .contentHash)
    }
}

public enum DeviceTrustState: String, Codable, Equatable, Sendable {
    case pending
    case trusted
    case revoked
}

public struct PairedDevice: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var createdAt: Date
    public var lastSeenAt: Date?
    public var trustState: DeviceTrustState

    public init(
        id: String,
        displayName: String,
        createdAt: Date,
        lastSeenAt: Date?,
        trustState: DeviceTrustState
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.trustState = trustState
    }
}

public enum IconAssetFormat: String, Codable, Equatable, Sendable {
    case png
}

public struct AppIconAsset: Codable, Equatable, Identifiable, Sendable {
    public var id: String { hash }
    public var hash: String
    public var format: IconAssetFormat
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var bytesLength: Int

    public init(
        hash: String,
        format: IconAssetFormat = .png,
        pixelWidth: Int,
        pixelHeight: Int,
        bytesLength: Int
    ) {
        self.hash = hash
        self.format = format
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.bytesLength = bytesLength
    }
}
