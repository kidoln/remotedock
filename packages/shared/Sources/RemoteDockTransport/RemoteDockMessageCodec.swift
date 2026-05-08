import Foundation
import RemoteDockProtocol

public extension RemoteDockMessage {
    func encodedData() throws -> Data {
        switch self {
        case let .hello(payload):
            try encode(type: .hello, payload: payload)
        case let .pairRequest(payload):
            try encode(type: .pairRequest, payload: payload)
        case let .pairApprove(payload):
            try encode(type: .pairApprove, payload: payload)
        case let .appsSnapshot(payload):
            try encode(type: .appsSnapshot, payload: payload)
        case let .runningAppsSnapshot(payload):
            try encode(type: .runningAppsSnapshot, payload: payload)
        case let .clipboardSnapshot(payload):
            try encode(type: .clipboardSnapshot, payload: payload)
        case let .clipboardDelta(payload):
            try encode(type: .clipboardDelta, payload: payload)
        case let .iconManifest(payload):
            try encode(type: .iconManifest, payload: payload)
        case let .iconRequest(payload):
            try encode(type: .iconRequest, payload: payload)
        case let .iconPayload(payload):
            try encode(type: .iconPayload, payload: payload)
        case let .activateAppCommand(payload):
            try encode(type: .activateAppCommand, payload: payload)
        case let .pasteClipboardItemCommand(payload):
            try encode(type: .pasteClipboardItemCommand, payload: payload)
        case let .commandResult(payload):
            try encode(type: .commandResult, payload: payload)
        case let .error(payload):
            try encode(type: .error, payload: payload)
        }
    }

    static func decode(from data: Data) throws -> RemoteDockMessage {
        let header = try RemoteDockProtocolCodec.decoder.decode(ProtocolEnvelopeHeader.self, from: data)
        switch header.type {
        case .hello:
            return .hello(try decodePayload(HelloPayload.self, from: data, expectedType: .hello))
        case .pairRequest:
            return .pairRequest(try decodePayload(PairRequestPayload.self, from: data, expectedType: .pairRequest))
        case .pairApprove:
            return .pairApprove(try decodePayload(PairApprovePayload.self, from: data, expectedType: .pairApprove))
        case .appsSnapshot:
            return .appsSnapshot(try decodePayload(AppsSnapshotPayload.self, from: data, expectedType: .appsSnapshot))
        case .runningAppsSnapshot:
            return .runningAppsSnapshot(try decodePayload(RunningAppsSnapshotPayload.self, from: data, expectedType: .runningAppsSnapshot))
        case .clipboardSnapshot:
            return .clipboardSnapshot(try decodePayload(ClipboardSnapshotPayload.self, from: data, expectedType: .clipboardSnapshot))
        case .clipboardDelta:
            return .clipboardDelta(try decodePayload(ClipboardDeltaPayload.self, from: data, expectedType: .clipboardDelta))
        case .iconManifest:
            return .iconManifest(try decodePayload(IconManifestPayload.self, from: data, expectedType: .iconManifest))
        case .iconRequest:
            return .iconRequest(try decodePayload(IconRequestPayload.self, from: data, expectedType: .iconRequest))
        case .iconPayload:
            return .iconPayload(try decodePayload(IconPayload.self, from: data, expectedType: .iconPayload))
        case .activateAppCommand:
            return .activateAppCommand(try decodePayload(ActivateAppCommandPayload.self, from: data, expectedType: .activateAppCommand))
        case .pasteClipboardItemCommand:
            return .pasteClipboardItemCommand(try decodePayload(PasteClipboardItemCommandPayload.self, from: data, expectedType: .pasteClipboardItemCommand))
        case .commandResult:
            return .commandResult(try decodePayload(CommandResultPayload.self, from: data, expectedType: .commandResult))
        case .error:
            return .error(try decodePayload(ErrorPayload.self, from: data, expectedType: .error))
        }
    }

    private func encode<Payload: Codable & Equatable & Sendable>(
        type: RemoteDockMessageType,
        payload: Payload
    ) throws -> Data {
        try RemoteDockProtocolCodec.encode(ProtocolEnvelope(type: type, payload: payload))
    }

    private static func decodePayload<Payload: Codable & Equatable & Sendable>(
        _ payloadType: Payload.Type,
        from data: Data,
        expectedType: RemoteDockMessageType
    ) throws -> Payload {
        try RemoteDockProtocolCodec.decode(payloadType, from: data, expectedType: expectedType).payload
    }
}
