import Foundation

public extension RemoteDockLanguage {
    func localizedString(_ key: String, bundle: Bundle = .main) -> String {
        let localizedBundle = bundle.localizedResourceBundle(for: self)
        let localizedValue = localizedBundle.localizedString(forKey: key, value: nil, table: nil)
        guard localizedValue != key else {
            return String(
                localized: String.LocalizationValue(key),
                bundle: bundle,
                locale: Locale(identifier: localeIdentifier)
            )
        }

        return localizedValue
    }

    func formattedLocalizedString(
        _ key: String,
        bundle: Bundle = .main,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: localizedString(key, bundle: bundle),
            locale: Locale(identifier: localeIdentifier),
            arguments: arguments
        )
    }
}

private extension Bundle {
    func localizedResourceBundle(for language: RemoteDockLanguage) -> Bundle {
        guard let path = path(forResource: language.localeIdentifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return self
        }

        return bundle
    }
}
