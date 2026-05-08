import Foundation

struct SettingsStore: Equatable {
    var selectedMacId: String?
    var pairingCodeInput = ""
    var savedPairingCode: String?
    var clipboardSyncEnabled = true
    var pasteConfirmationEnabled = true
}
