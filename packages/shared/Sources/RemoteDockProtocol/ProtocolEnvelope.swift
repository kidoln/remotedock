import Foundation
import RemoteDockCore

public enum RemoteDockMessageType: String, Codable, CaseIterable, Sendable {
    case hello
    case pairRequest
    case pairApprove
    case appsSnapshot
    case runningAppsSnapshot
    case clipboardSnapshot
    case clipboardDelta
    case iconManifest
    case iconRequest
    case iconPayload
    case activateAppCommand
    case pasteClipboardItemCommand
    case commandResult
    case error
}

public struct ProtocolEnvelope<Payload: Codable & Sendable>: Codable, Equatable, Sendable where Payload: Equatable {
    public var type: RemoteDockMessageType
    public var version: Int
    public var payload: Payload

    public init(type: RemoteDockMessageType, version: Int = ProtocolVersion.current, payload: Payload) {
        self.type = type
        self.version = version
        self.payload = payload
    }
}

public enum ProtocolVersion {
    public static let current = 1
}

public enum RemoteDockProtocolCodec {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encode<Payload: Codable & Sendable>(
        _ envelope: ProtocolEnvelope<Payload>
    ) throws -> Data {
        try encoder.encode(envelope)
    }

    public static func decode<Payload: Codable & Sendable & Equatable>(
        _ payloadType: Payload.Type,
        from data: Data,
        expectedType: RemoteDockMessageType
    ) throws -> ProtocolEnvelope<Payload> {
        let envelope = try decoder.decode(ProtocolEnvelope<Payload>.self, from: data)
        guard envelope.version == ProtocolVersion.current else {
            throw RemoteDockError.unsupportedProtocolVersion(envelope.version)
        }
        guard envelope.type == expectedType else {
            throw ProtocolDecodingError.unexpectedType(expected: expectedType, actual: envelope.type)
        }
        return envelope
    }
}

public enum ProtocolDecodingError: Error, Equatable, Sendable {
    case unexpectedType(expected: RemoteDockMessageType, actual: RemoteDockMessageType)
}
