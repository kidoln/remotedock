import Foundation
import RemoteDockCore

public struct HelloPayload: Codable, Equatable, Sendable {
    public var deviceId: String
    public var deviceName: String
    public var platform: RemoteDockPlatform
    public var supportedProtocolVersion: Int
    public var supportedProtocolVersions: ProtocolVersionRange
    public var appVersion: String?
    public var buildNumber: String?
    public var capabilities: [RemoteDockCapability]

    public init(
        deviceId: String,
        deviceName: String,
        platform: RemoteDockPlatform,
        supportedProtocolVersion: Int = ProtocolVersion.current,
        supportedProtocolVersions: ProtocolVersionRange = ProtocolVersion.supportedRange,
        appVersion: String? = nil,
        buildNumber: String? = nil,
        capabilities: [RemoteDockCapability]
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.supportedProtocolVersion = supportedProtocolVersion
        self.supportedProtocolVersions = supportedProtocolVersions
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.capabilities = capabilities
    }

    public var highestCompatibleProtocolVersion: Int? {
        ProtocolVersion.supportedRange.highestCommonVersion(with: supportedProtocolVersions)
    }

    public var isProtocolCompatible: Bool {
        highestCompatibleProtocolVersion != nil
    }

    private enum CodingKeys: String, CodingKey {
        case deviceId
        case deviceName
        case platform
        case supportedProtocolVersion
        case supportedProtocolVersions
        case appVersion
        case buildNumber
        case capabilities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        platform = try container.decode(RemoteDockPlatform.self, forKey: .platform)
        supportedProtocolVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .supportedProtocolVersion
        ) ?? ProtocolVersion.current
        supportedProtocolVersions = try container.decodeIfPresent(
            ProtocolVersionRange.self,
            forKey: .supportedProtocolVersions
        ) ?? ProtocolVersionRange(
            minimum: supportedProtocolVersion,
            maximum: supportedProtocolVersion
        )
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        buildNumber = try container.decodeIfPresent(String.self, forKey: .buildNumber)
        capabilities = try container.decode([RemoteDockCapability].self, forKey: .capabilities)
    }
}

public enum RemoteDockPlatform: String, Codable, Equatable, Sendable {
    case macOS
    case iOS
}

public enum RemoteDockCapability: String, Codable, Equatable, Sendable {
    case appActivation
    case runningApps
    case clipboardHistory
    case clipboardPaste
    case iconSync
}

public struct PairRequestPayload: Codable, Equatable, Sendable {
    public var deviceId: String
    public var deviceName: String
    public var requestedAt: Date

    public init(deviceId: String, deviceName: String, requestedAt: Date) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.requestedAt = requestedAt
    }
}

public struct PairApprovePayload: Codable, Equatable, Sendable {
    public var deviceId: String
    public var approvedAt: Date
    public var pairingCode: String

    public init(deviceId: String, approvedAt: Date, pairingCode: String) {
        self.deviceId = deviceId
        self.approvedAt = approvedAt
        self.pairingCode = pairingCode
    }
}

public struct AppsSnapshotPayload: Codable, Equatable, Sendable {
    public var apps: [PinnedApp]

    public init(apps: [PinnedApp]) {
        self.apps = apps
    }
}

public struct RunningAppsSnapshotPayload: Codable, Equatable, Sendable {
    public var apps: [RunningApp]

    public init(apps: [RunningApp]) {
        self.apps = apps
    }
}

public struct ClipboardSnapshotPayload: Codable, Equatable, Sendable {
    public var items: [ClipboardItem]

    public init(items: [ClipboardItem]) {
        self.items = items
    }
}

public enum ClipboardDeltaOperation: String, Codable, Equatable, Sendable {
    case inserted
    case deleted
    case cleared
}

public struct ClipboardDeltaPayload: Codable, Equatable, Sendable {
    public var operation: ClipboardDeltaOperation
    public var item: ClipboardItem?
    public var itemId: String?

    public init(operation: ClipboardDeltaOperation, item: ClipboardItem? = nil, itemId: String? = nil) {
        self.operation = operation
        self.item = item
        self.itemId = itemId
    }
}

public struct IconManifestPayload: Codable, Equatable, Sendable {
    public var assets: [AppIconAsset]

    public init(assets: [AppIconAsset]) {
        self.assets = assets
    }
}

public struct IconRequestPayload: Codable, Equatable, Sendable {
    public var hashes: [String]

    public init(hashes: [String]) {
        self.hashes = hashes
    }
}

public struct IconPayload: Codable, Equatable, Sendable {
    public var asset: AppIconAsset
    public var base64PNGData: String

    public init(asset: AppIconAsset, base64PNGData: String) {
        self.asset = asset
        self.base64PNGData = base64PNGData
    }
}

public enum CommandType: String, Codable, Equatable, Sendable {
    case activateApp
    case pasteClipboardItem
}

public struct ActivateAppCommandPayload: Codable, Equatable, Sendable {
    public var commandId: String
    public var issuedAt: Date
    public var bundleIdentifier: String
    public var appPath: String?

    public init(commandId: String, issuedAt: Date, bundleIdentifier: String, appPath: String? = nil) {
        self.commandId = commandId
        self.issuedAt = issuedAt
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
    }
}

public struct PasteClipboardItemCommandPayload: Codable, Equatable, Sendable {
    public var commandId: String
    public var issuedAt: Date
    public var clipboardItemId: String
    public var plainText: String
    public var richRepresentations: [ClipboardRepresentation]

    public init(
        commandId: String,
        issuedAt: Date,
        clipboardItemId: String,
        plainText: String,
        richRepresentations: [ClipboardRepresentation] = []
    ) {
        self.commandId = commandId
        self.issuedAt = issuedAt
        self.clipboardItemId = clipboardItemId
        self.plainText = plainText
        self.richRepresentations = richRepresentations
    }

    private enum CodingKeys: String, CodingKey {
        case commandId
        case issuedAt
        case clipboardItemId
        case plainText
        case richRepresentations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commandId = try container.decode(String.self, forKey: .commandId)
        issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        clipboardItemId = try container.decode(String.self, forKey: .clipboardItemId)
        plainText = try container.decode(String.self, forKey: .plainText)
        richRepresentations = try container.decodeIfPresent(
            [ClipboardRepresentation].self,
            forKey: .richRepresentations
        ) ?? []
    }
}

public struct CommandResultPayload: Codable, Equatable, Sendable {
    public var commandId: String
    public var commandType: CommandType
    public var succeeded: Bool
    public var message: String?
    public var completedAt: Date

    public init(
        commandId: String,
        commandType: CommandType,
        succeeded: Bool,
        message: String? = nil,
        completedAt: Date
    ) {
        self.commandId = commandId
        self.commandType = commandType
        self.succeeded = succeeded
        self.message = message
        self.completedAt = completedAt
    }
}

public struct ErrorPayload: Codable, Equatable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
