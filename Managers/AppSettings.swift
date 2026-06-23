import Foundation
import SwiftUI

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private enum Keys {
        static let defaultRestSeconds = "defaultRestSeconds"
        static let remindersEnabled = "remindersEnabled"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
    }
    
    private let defaults = UserDefaults.standard
    
    var defaultRestSeconds: Int {
        didSet { defaults.set(defaultRestSeconds, forKey: Keys.defaultRestSeconds) }
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
    
    private init() {
        let storedRest = defaults.object(forKey: Keys.defaultRestSeconds) as? Int
        defaultRestSeconds = storedRest ?? 90
        remindersEnabled = defaults.bool(forKey: Keys.remindersEnabled)
        reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 19
        reminderMinute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
    }
}
