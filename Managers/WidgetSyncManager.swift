import Foundation
import SwiftData
import WidgetKit

enum WidgetSyncManager {
    
    static func sync(workoutDays: [WorkoutDay], context: ModelContext? = nil) {
        let snapshots = workoutDays.map { day in
            WeekPlanSummary.DaySnapshot(
                dayName: day.dayName,
                isRestDay: day.isRestDay,
                totalSets: day.exercises.reduce(0) { $0 + $1.sets },
                exerciseNames: day.exercises
                    .sorted { $0.order < $1.order }
                    .map(\.name)
            )
        }
        
        let overview = WeekPlanSummary.buildOverview(from: snapshots)
        let todayName = WeekPlanSummary.todayDayName()
        let todayPlan = workoutDays.first { $0.dayName == todayName }
        
        let streak = context.map { WorkoutHistoryManager.currentStreak(context: $0) } ?? WidgetDataStore.streak
        let todaySnapshot = makeTodaySnapshot(plan: todayPlan, dayName: todayName, streak: streak)
        
        WidgetDataStore.update(today: todaySnapshot, weekOverview: overview)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private static func makeTodaySnapshot(plan: WorkoutDay?, dayName: String, streak: Int) -> WidgetDataStore.TodaySnapshot {
        guard let plan else {
            return WidgetDataStore.TodaySnapshot(
                completedSets: 0,
                totalSets: 0,
                completedExercises: 0,
                totalExercises: 0,
                dayName: dayName,
                isRestDay: false,
                isWorkoutComplete: false,
                exercisePreview: "",
                streak: streak
            )
        }
        
        if plan.isRestDay {
            return WidgetDataStore.TodaySnapshot(
                completedSets: 0,
                totalSets: 0,
                completedExercises: 0,
                totalExercises: 0,
                dayName: plan.dayName,
                isRestDay: true,
                isWorkoutComplete: false,
                exercisePreview: "",
                streak: streak
            )
        }
        
        let sortedExercises = plan.exercises.sorted { $0.order < $1.order }
        let completedSets = plan.exercises.reduce(0) { $0 + $1.effectiveCompletedSetCount }
        let totalSets = plan.exercises.reduce(0) { $0 + $1.sets }
        let completedExercises = plan.exercises.filter { $0.isFullyCompletedToday }.count
        let preview = sortedExercises.prefix(2).map(\.name).joined(separator: " · ")
        let isComplete = !sortedExercises.isEmpty && completedExercises == sortedExercises.count
        
        return WidgetDataStore.TodaySnapshot(
            completedSets: completedSets,
            totalSets: totalSets,
            completedExercises: completedExercises,
            totalExercises: sortedExercises.count,
            dayName: plan.dayName,
            isRestDay: false,
            isWorkoutComplete: isComplete,
            exercisePreview: preview,
            streak: streak
        )
    }
}
