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

public struct ClipboardItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var contentType: ClipboardContentType
    public var plainText: String
    public var sourceAppBundleId: String?
    public var createdAt: Date
    public var contentHash: String

    public init(
        id: String,
        contentType: ClipboardContentType = .text,
        plainText: String,
        sourceAppBundleId: String? = nil,
        createdAt: Date,
        contentHash: String
    ) {
        self.id = id
        self.contentType = contentType
        self.plainText = plainText
        self.sourceAppBundleId = sourceAppBundleId
        self.createdAt = createdAt
        self.contentHash = contentHash
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
