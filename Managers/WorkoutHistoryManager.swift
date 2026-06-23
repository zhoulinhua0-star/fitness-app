import Foundation
import SwiftData

enum WorkoutHistoryManager {
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    static func todayWeekdayString(from date: Date = .now) -> String {
        weekdayFormatter.string(from: date).replacingOccurrences(of: "星期", with: "周")
    }
    
    static func startOfDay(for date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    static func fetchTodaySession(context: ModelContext, date: Date = .now) -> WorkoutSession? {
        let dayStart = startOfDay(for: date)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.sessionDate == dayStart }
        )
        return try? context.fetch(descriptor).first
    }
    
    static func getOrCreateTodaySession(context: ModelContext, plan: WorkoutDay) -> WorkoutSession {
        if let existing = fetchTodaySession(context: context) {
            syncSessionMetadata(session: existing, plan: plan)
            return existing
        }
        
        let session = WorkoutSession(
            sessionDate: startOfDay(),
            dayName: plan.dayName,
            plannedSetCount: plannedSetCount(for: plan),
            completedSetCount: completedSetCount(for: plan)
        )
        context.insert(session)
        return session
    }
    
    static func plannedSetCount(for plan: WorkoutDay) -> Int {
        plan.exercises.reduce(0) { $0 + $1.sets }
    }
    
    static func completedSetCount(for plan: WorkoutDay) -> Int {
        plan.exercises.reduce(0) { $0 + $1.effectiveCompletedSetCount }
    }
    
    static func syncSessionMetadata(session: WorkoutSession, plan: WorkoutDay) {
        session.plannedSetCount = plannedSetCount(for: plan)
        session.completedSetCount = completedSetCount(for: plan)
        session.dayName = plan.dayName
        
        let allDone = !plan.exercises.isEmpty &&
            plan.exercises.allSatisfy { $0.isFullyCompletedToday }
        session.isComplete = allDone
        session.completedAt = allDone ? (session.completedAt ?? .now) : nil
    }
    
    static func logSet(
        context: ModelContext,
        session: WorkoutSession,
        exercise: Exercise,
        setIndex: Int,
        weight: Double?
    ) {
        let log = SetLog(
            exerciseName: exercise.name,
            setIndex: setIndex,
            reps: exercise.reps,
            weight: weight
        )
        log.session = session
        session.setLogs.append(log)
    }
    
    static func undoLastSetLog(
        context: ModelContext,
        session: WorkoutSession,
        exerciseName: String
    ) {
        guard let log = session.setLogs
            .filter({ $0.exerciseName == exerciseName })
            .max(by: { $0.setIndex < $1.setIndex }) else { return }
        context.delete(log)
        session.setLogs.removeAll { $0.persistentModelID == log.persistentModelID }
    }
    
    static func logRemainingSets(
        context: ModelContext,
        session: WorkoutSession,
        exercise: Exercise,
        startingAt setIndex: Int,
        weight: Double?
    ) {
        guard setIndex <= exercise.sets else { return }
        for index in setIndex...exercise.sets {
            logSet(context: context, session: session, exercise: exercise, setIndex: index, weight: weight)
        }
    }
    
    static func removeLogsFromSetIndex(
        context: ModelContext,
        session: WorkoutSession,
        exerciseName: String,
        fromSetIndex: Int
    ) {
        let logsToRemove = session.setLogs.filter {
            $0.exerciseName == exerciseName && $0.setIndex >= fromSetIndex
        }
        for log in logsToRemove {
            context.delete(log)
        }
        session.setLogs.removeAll { log in
            logsToRemove.contains { $0.persistentModelID == log.persistentModelID }
        }
    }
    
    static func lastPerformanceSummary(context: ModelContext, exerciseName: String) -> String? {
        let todayStart = startOfDay()
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.sessionDate < todayStart },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        descriptor.fetchLimit = 14
        
        guard let sessions = try? context.fetch(descriptor) else { return nil }
        
        for session in sessions {
            let logs = session.setLogs
                .filter { $0.exerciseName == exerciseName }
                .sorted { $0.setIndex < $1.setIndex }
            guard !logs.isEmpty else { continue }
            
            let setCount = logs.count
            let reps = logs.first?.reps ?? 0
            return "上次: \(setCount)组 × \(reps)次"
        }
        return nil
    }
    
    static func fetchRecentSessions(context: ModelContext, limit: Int = 30) -> [WorkoutSession] {
        var descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func currentStreak(context: ModelContext, threshold: Double = 0.8) -> Int {
        let sessions = fetchRecentSessions(context: context, limit: 60)
        guard !sessions.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var checkDate = startOfDay()
        
        if let todaySession = sessions.first(where: { calendar.isDate($0.sessionDate, inSameDayAs: checkDate) }) {
            if todaySession.plannedSetCount == 0 || todaySession.completionRate >= threshold {
                streak += 1
            } else {
                return 0
            }
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return streak }
            checkDate = previousDay
        } else {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = previousDay
        }
        
        while true {
            if let session = sessions.first(where: { calendar.isDate($0.sessionDate, inSameDayAs: checkDate) }) {
                if session.plannedSetCount > 0 && session.completionRate >= threshold {
                    streak += 1
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = previousDay
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return streak
    }
    
    static func weeklyDayStats(
        context: ModelContext,
        workoutDays: [WorkoutDay]
    ) -> [(dayName: String, plannedSets: Int, completedSets: Int)] {
        let dayOrder = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let calendar = Calendar.current
        let todayStart = startOfDay()
        
        return dayOrder.map { dayName in
            let plan = workoutDays.first { $0.dayName == dayName }
            let planned = plan.map { plannedSetCount(for: $0) } ?? 0
            
            let weekdayIndex = dayOrder.firstIndex(of: dayName) ?? 0
            let completed = sumCompletedSetsForWeekday(
                context: context,
                weekdayIndex: weekdayIndex,
                dayOrder: dayOrder,
                todayStart: todayStart,
                plan: plan
            )
            
            return (dayName, planned, completed)
        }
    }
    
    private static func sumCompletedSetsForWeekday(
        context: ModelContext,
        weekdayIndex: Int,
        dayOrder: [String],
        todayStart: Date,
        plan: WorkoutDay?
    ) -> Int {
        guard let plan, !plan.isRestDay else { return 0 }
        
        let calendar = Calendar.current
        var total = 0
        
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let weekday = (calendar.component(.weekday, from: date) + 5) % 7
            guard weekday == weekdayIndex else { continue }
            
            if calendar.isDateInToday(date), plan.dayName == dayOrder[weekdayIndex] {
                total += completedSetCount(for: plan)
            } else if let session = fetchSession(on: date, context: context),
                      session.dayName == dayOrder[weekdayIndex] {
                total += session.completedSetCount
            }
        }
        
        return total
    }
    
    private static func fetchSession(on date: Date, context: ModelContext) -> WorkoutSession? {
        let dayStart = startOfDay(for: date)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.sessionDate == dayStart }
        )
        return try? context.fetch(descriptor).first
    }
}
