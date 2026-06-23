import Foundation

enum WidgetDataStore {
    static let appGroupID = "group.com.zhoulinhua0-star.FitnessApp2026"
    
    private enum Keys {
        static let completedSets = "widgetCompletedSets"
        static let totalSets = "widgetTotalSets"
        static let completedExercises = "widgetCompletedExercises"
        static let totalExercises = "widgetTotalExercises"
        static let dayName = "widgetDayName"
        static let lastUpdated = "widgetLastUpdated"
    }
    
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    static func updateTodayProgress(
        completedSets: Int,
        totalSets: Int,
        completedExercises: Int,
        totalExercises: Int,
        dayName: String
    ) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(completedSets, forKey: Keys.completedSets)
        defaults.set(totalSets, forKey: Keys.totalSets)
        defaults.set(completedExercises, forKey: Keys.completedExercises)
        defaults.set(totalExercises, forKey: Keys.totalExercises)
        defaults.set(dayName, forKey: Keys.dayName)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
    }
    
    static var completedSets: Int {
        sharedDefaults?.integer(forKey: Keys.completedSets) ?? 0
    }
    
    static var totalSets: Int {
        sharedDefaults?.integer(forKey: Keys.totalSets) ?? 0
    }
    
    static var completedExercises: Int {
        sharedDefaults?.integer(forKey: Keys.completedExercises) ?? 0
    }
    
    static var totalExercises: Int {
        sharedDefaults?.integer(forKey: Keys.totalExercises) ?? 0
    }
    
    static var dayName: String {
        sharedDefaults?.string(forKey: Keys.dayName) ?? "今日"
    }
    
    static var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }
}
