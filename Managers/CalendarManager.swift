//
//  CalendarManager.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import EventKit
import SwiftData
import SwiftUI

@MainActor
class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    // 请求权限并同步
    func requestAccessAndSync(workoutDays: [WorkoutDay]) async -> Bool {
        do {
            let granted: Bool
            // 适配 iOS 17 及以上的最安全权限请求
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { success, error in
                        if let error = error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: success) }
                    }
                }
            }
            
            if granted {
                return try await syncToSystemCalendar(workoutDays: workoutDays)
            }
            return false
        } catch {
            print("日历操作失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 写入 iPhone 系统日历
    private func syncToSystemCalendar(workoutDays: [WorkoutDay]) async throws -> Bool {
        let calendars = eventStore.calendars(for: .event)
        
        // 1. 寻找或创建一个叫「我的健身课表」的独立日历分类
        var targetCalendar = calendars.first { $0.title == "我的健身课表" }
        if targetCalendar == nil {
            let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
            newCalendar.title = "我的健身课表"
            newCalendar.source = eventStore.sources.first(where: { $0.sourceType == .local }) ?? eventStore.defaultCalendarForNewEvents?.source
            try eventStore.saveCalendar(newCalendar, commit: true)
            targetCalendar = newCalendar
        }
        
        guard let calendar = targetCalendar else { return false }
        
        let now = Date()
        let sysCalendar = Calendar.current
        let startOfToday = sysCalendar.startOfDay(for: now)
        
        // 🧹 2. 大扫除：先清理未来 30 天内该日历下的所有旧日程，防止重复和不更新
        if let endOfClearPeriod = sysCalendar.date(byAdding: .day, value: 30, to: startOfToday) {
            let clearPredicate = eventStore.predicateForEvents(withStart: startOfToday, end: endOfClearPeriod, calendars: [calendar])
            let oldEvents = eventStore.events(matching: clearPredicate)
            for oldEvent in oldEvents {
                // 批量删除，不立刻提交，提升性能
                try eventStore.remove(oldEvent, span: .thisEvent, commit: false)
            }
            // 一次性提交所有删除操作
            try eventStore.commit()
        }
        
        // 🗓️ 3. 铺新床：把未来 7 天的最新课表写入系统日历
        for i in 0..<7 {
            guard let targetDate = sysCalendar.date(byAdding: .day, value: i, to: now) else { continue }
            
            // 获取当天是周几
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "EEEE"
            let weekdayStr = formatter.string(from: targetDate).replacingOccurrences(of: "星期", with: "周")
            
            // 匹配我们的课表
            if let plan = workoutDays.first(where: { $0.dayName == weekdayStr }), !plan.isRestDay, !plan.exercises.isEmpty {
                
                let startOfDay = sysCalendar.startOfDay(for: targetDate)
                
                let event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                event.title = "💪 今日训练：\(plan.exercises.first?.name ?? "")等"
                event.isAllDay = true
                event.startDate = startOfDay
                event.endDate = startOfDay
                
                // 把动作清单写进日历备注
                let notes = plan.exercises.map { "• \($0.name): \($0.sets)组 × \($0.reps)次" }.joined(separator: "\n")
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
