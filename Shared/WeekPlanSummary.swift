import Foundation

enum WeekPlanSummary {
    static let dayOrder = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private static let shortLabels = ["一", "二", "三", "四", "五", "六", "日"]
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    struct DaySnapshot {
        let dayName: String
        let isRestDay: Bool
        let totalSets: Int
        let exerciseNames: [String]
    }
    
    struct WeekDayDisplay: Codable, Equatable {
        let shortLabel: String
        let isRestDay: Bool
        let totalSets: Int
        let isToday: Bool
        let focusLabel: String
    }
    
    struct Overview: Codable, Equatable {
        let trainingDays: Int
        let restDays: Int
        let totalSets: Int
        let heaviestDayName: String?
        let heaviestDaySets: Int
        let weekDays: [WeekDayDisplay]
        let todayDayName: String
        let nextWorkoutDayName: String?
        let nextWorkoutPreview: String?
    }
    
    static func todayDayName(from date: Date = .now) -> String {
        weekdayFormatter.string(from: date).replacingOccurrences(of: "星期", with: "周")
    }
    
    static func buildOverview(from days: [DaySnapshot], todayDayName: String = todayDayName()) -> Overview {
        var trainingDays = 0
        var restDays = 0
        var totalSets = 0
        var heaviestDayName: String?
        var heaviestDaySets = 0
        var weekDays: [WeekDayDisplay] = []
        
        for (index, dayName) in dayOrder.enumerated() {
            guard let day = days.first(where: { $0.dayName == dayName }) else { continue }
            
            if day.isRestDay || day.totalSets == 0 && day.exerciseNames.isEmpty {
                if day.isRestDay { restDays += 1 }
            } else {
                trainingDays += 1
                totalSets += day.totalSets
                if day.totalSets > heaviestDaySets {
                    heaviestDaySets = day.totalSets
                    heaviestDayName = day.dayName
                }
            }
            
            weekDays.append(
                WeekDayDisplay(
                    shortLabel: shortLabels[index],
                    isRestDay: day.isRestDay,
                    totalSets: day.totalSets,
                    isToday: day.dayName == todayDayName,
                    focusLabel: focusLabel(for: day)
                )
            )
        }
        
        let next = nextWorkout(from: days, after: todayDayName)
        
        return Overview(
            trainingDays: trainingDays,
            restDays: restDays,
            totalSets: totalSets,
            heaviestDayName: heaviestDaySets > 0 ? heaviestDayName : nil,
            heaviestDaySets: heaviestDaySets,
            weekDays: weekDays,
            todayDayName: todayDayName,
            nextWorkoutDayName: next?.dayName,
            nextWorkoutPreview: next.map { preview(for: $0) }
        )
    }
    
    private static func focusLabel(for day: DaySnapshot) -> String {
        if day.isRestDay { return "休" }
        guard let first = day.exerciseNames.first else { return "待定" }
        if first.count <= 4 { return first }
        return String(first.prefix(4))
    }
    
    private static func preview(for day: DaySnapshot) -> String {
        let names = day.exerciseNames.prefix(2).joined(separator: " · ")
        if names.isEmpty { return "\(day.totalSets) 组" }
        if day.exerciseNames.count > 2 {
            return "\(names)…"
        }
        return names
    }
    
    private static func nextWorkout(from days: [DaySnapshot], after todayDayName: String) -> DaySnapshot? {
        guard let todayIndex = dayOrder.firstIndex(of: todayDayName) else { return nil }
        
        for offset in 1...7 {
            let dayName = dayOrder[(todayIndex + offset) % 7]
            guard let day = days.first(where: { $0.dayName == dayName }) else { continue }
            guard !day.isRestDay, day.totalSets > 0 || !day.exerciseNames.isEmpty else { continue }
            return day
        }
        return nil
    }
}
