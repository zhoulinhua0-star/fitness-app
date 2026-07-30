import Foundation
import SwiftUI

enum AppTextSizePreference: String, CaseIterable, Identifiable {
    case compact
    case standard
    case large

    var id: Self { self }

    var title: String {
        switch self {
        case .compact: AppLocalization.string("紧凑")
        case .standard: AppLocalization.string("标准")
        case .large: AppLocalization.string("大字")
        }
    }

    var detail: String {
        switch self {
        case .compact: AppLocalization.string("更高信息密度")
        case .standard: AppLocalization.string("舒适清晰，推荐使用")
        case .large: AppLocalization.string("跟随系统文字大小")
        }
    }

    func adjusted(from systemSize: DynamicTypeSize) -> DynamicTypeSize {
        let sizes: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
        ]
        guard let index = sizes.firstIndex(of: systemSize) else { return systemSize }

        let offset = switch self {
        case .compact: -2
        case .standard: -1
        case .large: 0
        }
        let minimumIndex = systemSize.isAccessibilitySize
            ? sizes.firstIndex(of: .accessibility1) ?? sizes.startIndex
            : sizes.startIndex
        return sizes[min(max(index + offset, minimumIndex), sizes.index(before: sizes.endIndex))]
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private enum Keys {
        static let defaultRestSeconds = "defaultRestSeconds"
        static let restNotificationsEnabled = "restNotificationsEnabled"
        static let cardioGoalNotificationsEnabled = "cardioGoalNotificationsEnabled"
        static let restSoundEnabled = "restSoundEnabled"
        static let restHapticsEnabled = "restHapticsEnabled"
        static let remindersEnabled = "remindersEnabled"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let remindersOnPlannedDaysOnly = "remindersOnPlannedDaysOnly"
        static let skipReminderWhenCompleted = "skipReminderWhenCompleted"
        static let textSizePreference = "textSizePreference"
        static let languagePreference = AppLocalization.preferenceDefaultsKey
    }
    
    private let defaults = UserDefaults.standard
    
    var defaultRestSeconds: Int {
        didSet { defaults.set(defaultRestSeconds, forKey: Keys.defaultRestSeconds) }
    }

    var restNotificationsEnabled: Bool {
        didSet { defaults.set(restNotificationsEnabled, forKey: Keys.restNotificationsEnabled) }
    }

    var cardioGoalNotificationsEnabled: Bool {
        didSet { defaults.set(cardioGoalNotificationsEnabled, forKey: Keys.cardioGoalNotificationsEnabled) }
    }

    var restSoundEnabled: Bool {
        didSet { defaults.set(restSoundEnabled, forKey: Keys.restSoundEnabled) }
    }

    var restHapticsEnabled: Bool {
        didSet { defaults.set(restHapticsEnabled, forKey: Keys.restHapticsEnabled) }
    }
    
    var remindersEnabled: Bool {
        didSet { defaults.set(remindersEnabled, forKey: Keys.remindersEnabled) }
    }
    
    var reminderHour: Int {
        didSet { defaults.set(reminderHour, forKey: Keys.reminderHour) }
    }
    
    var reminderMinute: Int {
        didSet { defaults.set(reminderMinute, forKey: Keys.reminderMinute) }
    }

    var remindersOnPlannedDaysOnly: Bool {
        didSet { defaults.set(remindersOnPlannedDaysOnly, forKey: Keys.remindersOnPlannedDaysOnly) }
    }

    var skipReminderWhenCompleted: Bool {
        didSet { defaults.set(skipReminderWhenCompleted, forKey: Keys.skipReminderWhenCompleted) }
    }

    var textSizePreference: AppTextSizePreference {
        didSet { defaults.set(textSizePreference.rawValue, forKey: Keys.textSizePreference) }
    }

    var languagePreference: AppLanguagePreference {
        didSet {
            defaults.set(languagePreference.rawValue, forKey: Keys.languagePreference)
            WidgetDataStore.languageIdentifier = languagePreference.resolvedIdentifier()
        }
    }
    
    private init() {
        let storedRest = defaults.object(forKey: Keys.defaultRestSeconds) as? Int
        defaultRestSeconds = storedRest ?? 90
        restNotificationsEnabled = defaults.object(forKey: Keys.restNotificationsEnabled) as? Bool ?? true
        cardioGoalNotificationsEnabled = defaults.object(
            forKey: Keys.cardioGoalNotificationsEnabled
        ) as? Bool ?? true
        restSoundEnabled = defaults.object(forKey: Keys.restSoundEnabled) as? Bool ?? true
        restHapticsEnabled = defaults.object(forKey: Keys.restHapticsEnabled) as? Bool ?? true
        remindersEnabled = defaults.bool(forKey: Keys.remindersEnabled)
        reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 19
        reminderMinute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
        remindersOnPlannedDaysOnly = defaults.object(forKey: Keys.remindersOnPlannedDaysOnly) as? Bool ?? true
        skipReminderWhenCompleted = defaults.object(forKey: Keys.skipReminderWhenCompleted) as? Bool ?? true
        textSizePreference = AppTextSizePreference(
            rawValue: defaults.string(forKey: Keys.textSizePreference) ?? ""
        ) ?? .standard
        languagePreference = AppLanguagePreference(
            rawValue: defaults.string(forKey: Keys.languagePreference) ?? ""
        ) ?? .system
        WidgetDataStore.languageIdentifier = languagePreference.resolvedIdentifier()
    }
}
