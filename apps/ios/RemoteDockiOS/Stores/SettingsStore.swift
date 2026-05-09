import Foundation
import RemoteDockCore

enum PhoneIconGridCount: Int, CaseIterable, Identifiable {
    case four = 4
    case three = 3
    case two = 2

    var id: Int {
        rawValue
    }

    var title: String {
        title(for: .simplifiedChinese)
    }

    func title(for language: RemoteDockLanguage) -> String {
        switch self {
        case .four:
            return language.localizedString("setting.size.small")
        case .three:
            return language.localizedString("setting.size.medium")
        case .two:
            return language.localizedString("setting.size.large")
        }
    }
}

enum PhoneClipboardFontSize: Int, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: Int {
        rawValue
    }

    var title: String {
        title(for: .simplifiedChinese)
    }

    func title(for language: RemoteDockLanguage) -> String {
        switch self {
        case .small:
            return language.localizedString("setting.size.small")
        case .medium:
            return language.localizedString("setting.size.medium")
        case .large:
            return language.localizedString("setting.size.large")
        }
    }
}

struct SettingsStore: Equatable {
    var selectedMacId: String?
    var pairingCodeInput = ""
    var savedPairingCode: String?
    var remoteLanguage: RemoteDockLanguage = .english
    var movePastedClipboardItemToTop = true
    var moveActivatedRunningAppToTop = true
    var iconGridCount: PhoneIconGridCount = .four
    var clipboardFontSize: PhoneClipboardFontSize = .small
}
