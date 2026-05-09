import Foundation

public enum RemoteDockLanguage: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String {
        rawValue
    }

    public var localeIdentifier: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    public static func resolved(from languageCode: String?) -> RemoteDockLanguage? {
        guard let languageCode else {
            return nil
        }

        let normalizedCode = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        guard !normalizedCode.isEmpty else {
            return nil
        }

        if normalizedCode == english.rawValue || normalizedCode.hasPrefix("en") {
            return .english
        }

        if normalizedCode == simplifiedChinese.rawValue.lowercased() ||
            normalizedCode.hasPrefix("zh") {
            return .simplifiedChinese
        }

        return nil
    }

    public static func resolved(fromPreferredLanguages preferredLanguages: [String]) -> RemoteDockLanguage {
        guard let firstPreferredLanguage = preferredLanguages.first else {
            return .english
        }

        return resolved(from: firstPreferredLanguage) ?? .english
    }
}
