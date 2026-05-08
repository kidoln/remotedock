import Foundation

struct SettingsStore: Equatable {
    var selectedMacId: String?
    var clipboardSyncEnabled = true
    var pasteConfirmationEnabled = true
}
