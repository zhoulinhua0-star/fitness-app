//
//  CalendarManager.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import EventKit
import SwiftData
import SwiftUI

enum CalendarAuthorizationState: Equatable {
    case notDetermined
    case allowed
    case denied
    case restricted
}

enum CalendarSyncResult: Equatable {
    case success
    case permissionDenied
    case restricted
    case failed
}

@MainActor
class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    var authorizationState: CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .allowed
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined, .writeOnly:
            return .notDetermined
        default:
            return .notDetermined
        }
    }

    // 请求权限并同步
    func requestAccessAndSync(workoutDays: [WorkoutDay]) async -> CalendarSyncResult {
        do {
            switch authorizationState {
            case .denied:
                return .permissionDenied
            case .restricted:
                return .restricted
            case .allowed:
                break
            case .notDetermined:
                guard try await eventStore.requestFullAccessToEvents() else {
                    return .permissionDenied
                }
            }

            eventStore.reset()
            return try await syncToSystemCalendar(workoutDays: workoutDays)
                ? .success
                : .failed
        } catch {
            print("日历操作失败: \(error.localizedDescription)")
            return .failed
        }
    }
    
    // 写入 iPhone 系统日历
    private func syncToSystemCalendar(workoutDays: [WorkoutDay]) async throws -> Bool {
        let calendars = eventStore.calendars(for: .event)
        
        // 1. 寻找或创建一个叫「我的健身课表」的独立日历分类
        let calendarTitle = AppLocalization.string("我的健身课表")
        var targetCalendar = calendars.first {
            $0.title == calendarTitle ||
                $0.title == "我的健身课表" ||
                $0.title == "My Workout Plan"
        }
        if targetCalendar == nil {
            let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
            newCalendar.title = calendarTitle
            newCalendar.source = eventStore.sources.first(where: { $0.sourceType == .local }) ?? eventStore.defaultCalendarForNewEvents?.source
            try eventStore.saveCalendar(newCalendar, commit: true)
            targetCalendar = newCalendar
        }
        
        guard let calendar = targetCalendar else { return false }
        if calendar.title != calendarTitle {
            calendar.title = calendarTitle
            try eventStore.saveCalendar(calendar, commit: true)
        }
        
        let now = Date()
        let sysCalendar = Calendar.current
        let startOfToday = sysCalendar.startOfDay(for: now)
        
        // 🧹 2. 大扫除：先清理未来 30 天内该日历下的所有旧日程，防止重复和不更新
        if let endOfClearPeriod = sysCalendar.date(byAdding: .day, value: 28, to: startOfToday) {
            let clearPredicate = eventStore.predicateForEvents(withStart: startOfToday, end: endOfClearPeriod, calendars: [calendar])
            let oldEvents = eventStore.events(matching: clearPredicate)
            for oldEvent in oldEvents {
                // 批量删除，不立刻提交，提升性能
                try eventStore.remove(oldEvent, span: .thisEvent, commit: false)
            }
            // 一次性提交所有删除操作
            try eventStore.commit()
        }
        
        // 🗓️ 3. 铺新床：把未来 4 周的最新课表写入系统日历
        for i in 0..<28 {
            guard let targetDate = sysCalendar.date(byAdding: .day, value: i, to: now) else { continue }
            
            let weekdayStr = Self.weekdayFormatter
                .string(from: targetDate)
                .replacingOccurrences(of: "星期", with: "周")
            
            // 匹配我们的课表
            if let plan = workoutDays.first(where: { $0.dayName == weekdayStr }), !plan.isRestDay, !plan.exercises.isEmpty {
                
                let startOfDay = sysCalendar.startOfDay(for: targetDate)
                
                let event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                let firstExercise = plan.exercises.first
                    .map { ExerciseLibrary.displayName(for: $0.name) } ?? ""
                event.title = AppLocalization.format("💪 今日训练：%@等", firstExercise)
                event.isAllDay = true
                event.startDate = startOfDay
                event.endDate = sysCalendar.date(byAdding: .day, value: 1, to: startOfDay)
                
                // 把动作清单写进日历备注
                let notes = plan.exercises.map { exercise in
                    if exercise.isCardio {
                        return AppLocalization.format(
                            "• %@: %@",
                            ExerciseLibrary.displayName(for: exercise.name),
                            ExerciseFormatting.shortDuration(exercise.targetDurationSeconds)
                        )
                    }
                    return AppLocalization.format(
                        "• %@: %lld组 × %lld次",
                        ExerciseLibrary.displayName(for: exercise.name),
                        exercise.sets,
                        exercise.reps
                    )
                }.joined(separator: "\n")
                event.notes = notes
                
                // 逐个保存新日程，不立刻提交
                try eventStore.save(event, span: .thisEvent, commit: false)
            }
        }
        
        // 一次性提交所有新增操作
        try eventStore.commit()
        
        return true
    }
}
