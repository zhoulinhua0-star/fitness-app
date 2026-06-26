import Foundation

enum WidgetDataStore {
    static let appGroupID = "group.com.zhoulinhua0-star.FitnessApp2026"
    
    private enum Keys {
        static let completedSets = "widgetCompletedSets"
        static let totalSets = "widgetTotalSets"
        static let completedExercises = "widgetCompletedExercises"
        static let totalExercises = "widgetTotalExercises"
        static let dayName = "widgetDayName"
        static let isRestDay = "widgetIsRestDay"
        static let isWorkoutComplete = "widgetIsWorkoutComplete"
        static let exercisePreview = "widgetExercisePreview"
        static let streak = "widgetStreak"
        static let nextWorkoutDayName = "widgetNextWorkoutDayName"
        static let nextWorkoutPreview = "widgetNextWorkoutPreview"
        static let weekOverviewJSON = "widgetWeekOverviewJSON"
        static let lastUpdated = "widgetLastUpdated"
    }
    
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    struct TodaySnapshot {
        let completedSets: Int
        let totalSets: Int
        let completedExercises: Int
        let totalExercises: Int
        let dayName: String
        let isRestDay: Bool
        let isWorkoutComplete: Bool
        let exercisePreview: String
        let streak: Int
    }
    
    static func update(today: TodaySnapshot, weekOverview: WeekPlanSummary.Overview) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(today.completedSets, forKey: Keys.completedSets)
        defaults.set(today.totalSets, forKey: Keys.totalSets)
        defaults.set(today.completedExercises, forKey: Keys.completedExercises)
        defaults.set(today.totalExercises, forKey: Keys.totalExercises)
        defaults.set(today.dayName, forKey: Keys.dayName)
        defaults.set(today.isRestDay, forKey: Keys.isRestDay)
        defaults.set(today.isWorkoutComplete, forKey: Keys.isWorkoutComplete)
        defaults.set(today.exercisePreview, forKey: Keys.exercisePreview)
        defaults.set(today.streak, forKey: Keys.streak)
        defaults.set(weekOverview.nextWorkoutDayName, forKey: Keys.nextWorkoutDayName)
        defaults.set(weekOverview.nextWorkoutPreview, forKey: Keys.nextWorkoutPreview)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
        
        if let data = try? JSONEncoder().encode(weekOverview) {
            defaults.set(data, forKey: Keys.weekOverviewJSON)
        }
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
    
    static var isRestDay: Bool {
        sharedDefaults?.bool(forKey: Keys.isRestDay) ?? false
    }
    
    static var isWorkoutComplete: Bool {
        sharedDefaults?.bool(forKey: Keys.isWorkoutComplete) ?? false
    }
    
    static var exercisePreview: String {
        sharedDefaults?.string(forKey: Keys.exercisePreview) ?? ""
    }
    
    static var streak: Int {
        sharedDefaults?.integer(forKey: Keys.streak) ?? 0
    }
    
    static var nextWorkoutDayName: String? {
        sharedDefaults?.string(forKey: Keys.nextWorkoutDayName)
    }
    
    static var nextWorkoutPreview: String? {
        sharedDefaults?.string(forKey: Keys.nextWorkoutPreview)
    }
    
    static var weekOverview: WeekPlanSummary.Overview? {
        guard
            let data = sharedDefaults?.data(forKey: Keys.weekOverviewJSON),
            let overview = try? JSONDecoder().decode(WeekPlanSummary.Overview.self, from: data)
        else { return nil }
        return overview
    }
    
    static var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }
}
