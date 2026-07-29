import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable, Codable {
    case system
    case simplifiedChinese
    case english

    var id: Self { self }

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .simplifiedChinese: "zh-Hans"
        case .english: "en"
        }
    }

    var languageName: String {
        switch self {
        case .system:
            AppLocalization.string("跟随 iPhone")
        case .simplifiedChinese:
            "简体中文"
        case .english:
            "English"
        }
    }

    func resolvedIdentifier(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        if let localeIdentifier {
            return localeIdentifier
        }
        let preferred = preferredLanguages.first ?? Locale.current.identifier
        return preferred.lowercased().hasPrefix("zh") ? "zh-Hans" : "en"
    }

    func resolvedLocale() -> Locale {
        Locale(identifier: resolvedIdentifier())
    }
}

enum AppLocalization {
    static let preferenceDefaultsKey = "appLanguagePreference"

    static var currentLanguageIdentifier: String {
        let rawValue = UserDefaults.standard.string(forKey: preferenceDefaultsKey) ?? ""
        let preference = AppLanguagePreference(rawValue: rawValue) ?? .system
        return preference.resolvedIdentifier()
    }

    static func string(
        _ key: String,
        languageIdentifier: String = currentLanguageIdentifier,
        bundle: Bundle = .main
    ) -> String {
        localizedBundle(for: languageIdentifier, in: bundle)
            .localizedString(forKey: key, value: key, table: nil)
    }

    static func format(
        _ key: String,
        languageIdentifier: String = currentLanguageIdentifier,
        bundle: Bundle = .main,
        _ arguments: CVarArg...
    ) -> String {
        let format = string(key, languageIdentifier: languageIdentifier, bundle: bundle)
        return String(
            format: format,
            locale: Locale(identifier: languageIdentifier),
            arguments: arguments
        )
    }

    private static func localizedBundle(
        for languageIdentifier: String,
        in bundle: Bundle
    ) -> Bundle {
        let candidates = languageIdentifier.lowercased().hasPrefix("zh")
            ? ["zh-Hans", "zh"]
            : ["en"]

        for candidate in candidates {
            if let path = bundle.path(forResource: candidate, ofType: "lproj"),
               let localizedBundle = Bundle(path: path) {
                return localizedBundle
            }
        }
        return bundle
    }
}
