import Foundation

public protocol ClipboardHistoryStore: Sendable {
    func loadClipboardHistory() async throws -> [ClipboardItem]
    func saveClipboardHistory(_ items: [ClipboardItem]) async throws
    func clearClipboardHistory() async throws
}

public protocol PairedDeviceStore: Sendable {
    func loadPairedDevices() async throws -> [PairedDevice]
    func savePairedDevices(_ devices: [PairedDevice]) async throws
}

public protocol IconCacheStore: Sendable {
    func loadIcon(hash: String) async throws -> Data?
    func saveIcon(hash: String, data: Data) async throws
    func removeIcon(hash: String) async throws
}
