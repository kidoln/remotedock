import Foundation
import RemoteDockCore
import RemoteDockProtocol
import RemoteDockTransport

struct CommandDispatcher {
    let transport: any TransportSession

    func activate(_ app: PinnedApp) async throws {
        let payload = ActivateAppCommandPayload(
            commandId: UUID().uuidString,
            issuedAt: Date(),
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.appPath
        )
        try await transport.send(.activateAppCommand(payload))
    }

    func activate(_ app: RunningApp) async throws {
        let payload = ActivateAppCommandPayload(
            commandId: UUID().uuidString,
            issuedAt: Date(),
            bundleIdentifier: app.bundleIdentifier
        )
        try await transport.send(.activateAppCommand(payload))
    }

    func paste(_ item: ClipboardItem) async throws {
        let payload = PasteClipboardItemCommandPayload(
            commandId: UUID().uuidString,
            issuedAt: Date(),
            clipboardItemId: item.id,
            plainText: item.plainText
        )
        try await transport.send(.pasteClipboardItemCommand(payload))
    }
}
