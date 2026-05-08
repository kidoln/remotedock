import Foundation

enum PhoneIconGridCount: Int, CaseIterable, Identifiable {
    case four = 4
    case three = 3
    case two = 2

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .four:
            return "小"
        case .three:
            return "中"
        case .two:
            return "大"
        }
    }
}

struct SettingsStore: Equatable {
    var selectedMacId: String?
    var pairingCodeInput = ""
    var savedPairingCode: String?
    var movePastedClipboardItemToTop = true
    var iconGridCount: PhoneIconGridCount = .four
}
