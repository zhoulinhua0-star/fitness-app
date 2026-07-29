import Foundation

enum WeekdayDisplay {
    static func label(for storedDayName: String) -> String {
        let localized = AppLocalization.string(storedDayName)
        guard AppLocalization.currentLanguageIdentifier.hasPrefix("en") else {
            return localized
        }
        return String(localized.prefix(3))
    }

    static func fullLabel(
        for storedDayName: String,
        languageIdentifier: String = AppLocalization.currentLanguageIdentifier
    ) -> String {
        AppLocalization.string(storedDayName, languageIdentifier: languageIdentifier)
    }
}
