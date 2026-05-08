import AppKit
import ApplicationServices
import Foundation
import RemoteDockCore
import RemoteDockProtocol

@MainActor
final class MacCommandExecutor {
    private let inbox = CommandInbox<CommandResultPayload>()

    func handleActivateAppCommand(_ payload: ActivateAppCommandPayload) async -> CommandResultPayload {
        if let cached = await inbox.cachedResult(for: payload.commandId) {
            return cached
        }

        let result: CommandResultPayload
        do {
            try await activateApp(bundleIdentifier: payload.bundleIdentifier, appPath: payload.appPath)
            result = CommandResultPayload(
                commandId: payload.commandId,
                commandType: .activateApp,
                succeeded: true,
                completedAt: Date()
            )
        } catch {
            result = CommandResultPayload(
                commandId: payload.commandId,
                commandType: .activateApp,
                succeeded: false,
                message: String(describing: error),
                completedAt: Date()
            )
        }

        await inbox.store(result, for: payload.commandId)
        return result
    }

    func handlePasteClipboardItemCommand(_ payload: PasteClipboardItemCommandPayload) async -> CommandResultPayload {
        if let cached = await inbox.cachedResult(for: payload.commandId) {
            return cached
        }

        let result: CommandResultPayload
        do {
            try await pasteIntoFrontmostApp(
                plainText: payload.plainText,
                richRepresentations: payload.richRepresentations
            )
            result = CommandResultPayload(
                commandId: payload.commandId,
                commandType: .pasteClipboardItem,
                succeeded: true,
                completedAt: Date()
            )
        } catch {
            result = CommandResultPayload(
                commandId: payload.commandId,
                commandType: .pasteClipboardItem,
                succeeded: false,
                message: String(describing: error),
                completedAt: Date()
            )
        }

        await inbox.store(result, for: payload.commandId)
        return result
    }

    func activateApp(bundleIdentifier: String, appPath: String?) async throws {
        let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        if let runningApp {
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        guard let appPath else {
            throw MacCommandExecutorError.applicationNotFound(bundleIdentifier)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        try await NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: configuration)
    }

    func pasteIntoFrontmostApp(_ text: String) async throws {
        try await pasteIntoFrontmostApp(plainText: text)
    }

    func pasteIntoFrontmostApp(
        plainText: String,
        richRepresentations: [ClipboardRepresentation] = []
    ) async throws {
        guard AXIsProcessTrusted() else {
            throw RemoteDockError.permissionDenied("Accessibility")
        }

        NSPasteboard.general.clearContents()
        writeClipboardContents(plainText: plainText, richRepresentations: richRepresentations)

        try await Task.sleep(for: .milliseconds(120))
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            throw MacCommandExecutorError.pasteEventCreationFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func writeClipboardContents(
        plainText: String,
        richRepresentations: [ClipboardRepresentation]
    ) {
        let pasteboard = NSPasteboard.general
        let writableTypes = richRepresentations
            .map { pasteboardType(for: $0.kind) }
            .filter { $0 != .string } + [.string]
        pasteboard.declareTypes(writableTypes, owner: nil)

        for representation in richRepresentations {
            pasteboard.setData(representation.data, forType: pasteboardType(for: representation.kind))
        }

        pasteboard.setString(plainText, forType: .string)
    }

    private func pasteboardType(for kind: ClipboardRepresentationKind) -> NSPasteboard.PasteboardType {
        switch kind {
        case .rtf:
            .rtf
        case .rtfd:
            .rtfd
        case .html:
            .html
        default:
            NSPasteboard.PasteboardType(kind.pasteboardTypeIdentifier)
        }
    }
}

enum MacCommandExecutorError: Error, Equatable {
    case applicationNotFound(String)
    case pasteEventCreationFailed
}
