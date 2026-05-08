import Foundation

enum PhoneIconGridCount: Int, CaseIterable, Identifiable {
    case four = 4
    case three = 3
    case two = 2

    var id: Int {
        rawValue
    }

    var title: String {
        "\(rawValue)"
    }
}

struct SettingsStore: Equatable {
    var selectedMacId: String?
    var pairingCodeInput = ""
    var savedPairingCode: String?
    var clipboardSyncEnabled = true
    var pasteConfirmationEnabled = true
    var iconGridCount: PhoneIconGridCount = .four
}
