import Foundation
import SwiftUI

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private enum Keys {
        static let defaultRestSeconds = "defaultRestSeconds"
        static let restNotificationsEnabled = "restNotificationsEnabled"
        static let restSoundEnabled = "restSoundEnabled"
        static let restHapticsEnabled = "restHapticsEnabled"
        static let remindersEnabled = "remindersEnabled"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let remindersOnPlannedDaysOnly = "remindersOnPlannedDaysOnly"
        static let skipReminderWhenCompleted = "skipReminderWhenCompleted"
    }
    
    private let defaults = UserDefaults.standard
    
    var defaultRestSeconds: Int {
        didSet { defaults.set(defaultRestSeconds, forKey: Keys.defaultRestSeconds) }
    }

    var restNotificationsEnabled: Bool {
        didSet { defaults.set(restNotificationsEnabled, forKey: Keys.restNotificationsEnabled) }
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
    
    private init() {
        let storedRest = defaults.object(forKey: Keys.defaultRestSeconds) as? Int
        defaultRestSeconds = storedRest ?? 90
        restNotificationsEnabled = defaults.object(forKey: Keys.restNotificationsEnabled) as? Bool ?? true
        restSoundEnabled = defaults.object(forKey: Keys.restSoundEnabled) as? Bool ?? true
        restHapticsEnabled = defaults.object(forKey: Keys.restHapticsEnabled) as? Bool ?? true
        remindersEnabled = defaults.bool(forKey: Keys.remindersEnabled)
        reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 19
        reminderMinute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
        remindersOnPlannedDaysOnly = defaults.object(forKey: Keys.remindersOnPlannedDaysOnly) as? Bool ?? true
        skipReminderWhenCompleted = defaults.object(forKey: Keys.skipReminderWhenCompleted) as? Bool ?? true
    }
}
