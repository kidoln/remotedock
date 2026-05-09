import Foundation
import RemoteDockCore

struct LanguageSettingsService {
    private let defaults: UserDefaults
    private let defaultsKey = "remoteDock.mac.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> RemoteDockLanguage {
        if let storedLanguageCode = defaults.string(forKey: defaultsKey),
           let storedLanguage = RemoteDockLanguage.resolved(from: storedLanguageCode) {
            return storedLanguage
        }

        return RemoteDockLanguage.resolved(fromPreferredLanguages: Locale.preferredLanguages)
    }

    func save(_ language: RemoteDockLanguage) {
        defaults.set(language.rawValue, forKey: defaultsKey)
    }
}
