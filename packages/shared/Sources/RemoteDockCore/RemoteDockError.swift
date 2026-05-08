import Foundation

public enum RemoteDockError: Error, Equatable, Sendable {
    case invalidClipboardText
    case commandAlreadyHandled
    case unsupportedProtocolVersion(Int)
    case transportUnavailable
    case permissionDenied(String)
    case storageFailure(String)
}
