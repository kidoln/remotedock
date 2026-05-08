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
                contentType: payload.contentType,
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
        contentType: ClipboardContentType = .text,
        plainText: String,
        richRepresentations: [ClipboardRepresentation] = []
    ) async throws {
        guard AXIsProcessTrusted() else {
            throw RemoteDockError.permissionDenied("Accessibility")
        }

        try writeClipboardContents(
            contentType: contentType,
            plainText: plainText,
            richRepresentations: richRepresentations
        )

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
        contentType: ClipboardContentType,
        plainText: String,
        richRepresentations: [ClipboardRepresentation]
    ) throws {
        let validRepresentations = richRepresentations.filter { representation in
            !representation.data.isEmpty && (contentType != .image || representation.kind.isImage)
        }
        let representationTypes = validRepresentations
            .map { pasteboardType(for: $0.kind) }
            .filter { $0 != .string }
        let writableTypes: [NSPasteboard.PasteboardType] = switch contentType {
        case .text:
            representationTypes + [.string]
        case .image:
            representationTypes.isEmpty ? [.png] : representationTypes
        }
        guard !writableTypes.isEmpty else {
            throw MacCommandExecutorError.invalidClipboardPayload
        }
        if contentType == .image && richRepresentations.isEmpty {
            throw MacCommandExecutorError.invalidClipboardPayload
        }
        if contentType == .image && validRepresentations.isEmpty {
            throw MacCommandExecutorError.invalidClipboardPayload
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes(writableTypes, owner: nil)

        for representation in validRepresentations {
            pasteboard.setData(representation.data, forType: pasteboardType(for: representation.kind))
        }

        if contentType == .text {
            pasteboard.setString(plainText, forType: .string)
        }
    }

    private func pasteboardType(for kind: ClipboardRepresentationKind) -> NSPasteboard.PasteboardType {
        switch kind {
        case .rtf:
            .rtf
        case .rtfd:
            .rtfd
        case .html:
            .html
        case .png:
            .png
        case .jpeg:
            NSPasteboard.PasteboardType("public.jpeg")
        case .tiff:
            .tiff
        case .gif:
            NSPasteboard.PasteboardType("com.compuserve.gif")
        case .heic:
            NSPasteboard.PasteboardType("public.heic")
        case .heif:
            NSPasteboard.PasteboardType("public.heif")
        default:
            NSPasteboard.PasteboardType(kind.pasteboardTypeIdentifier)
        }
    }
}

enum MacCommandExecutorError: Error, Equatable {
    case applicationNotFound(String)
    case invalidClipboardPayload
    case pasteEventCreationFailed
}
