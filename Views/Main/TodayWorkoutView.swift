//
//  TodayWorkoutView.swift
//  FitnessApp
//

import SwiftUI
import SwiftData

struct TodayWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutDays: [WorkoutDay]
    @State private var expandedExerciseID: PersistentIdentifier?
    @State private var didCelebrateFullWorkout = false
    @State private var showCompletionSummary = false
    @State private var todaySession: WorkoutSession?
    
    var todayPlan: WorkoutDay? {
        let todayString = WorkoutHistoryManager.todayWeekdayString()
        return workoutDays.first { $0.dayName == todayString }
    }
    
    var completedExerciseCount: Int {
        guard let plan = todayPlan else { return 0 }
        return plan.exercises.filter { $0.isFullyCompletedToday }.count
    }
    
    var completedSetCount: Int {
        guard let plan = todayPlan else { return 0 }
        return plan.exercises.reduce(0) { $0 + $1.effectiveCompletedSetCount }
    }
    
    var totalSetCount: Int {
        guard let plan = todayPlan else { return 0 }
        return plan.exercises.reduce(0) { $0 + $1.sets }
    }
    
    var progress: Double {
        guard totalSetCount > 0 else { return 0 }
        return Double(completedSetCount) / Double(totalSetCount)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if let plan = todayPlan {
                    if plan.isRestDay {
                        restDayView
                    } else if plan.exercises.isEmpty {
                        emptyPlanView
                    } else {
                        workoutListView(plan: plan)
                    }
                } else {
                    Text("未找到计划").foregroundColor(.secondary)
                }
                
                if showCompletionSummary, let plan = todayPlan {
                    WorkoutCompletionSummaryView(
                        completedSets: completedSetCount,
                        totalSets: totalSetCount,
                        completedExercises: completedExerciseCount,
                        totalExercises: plan.exercises.count,
                        onDismiss: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showCompletionSummary = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showCompletionSummary)
            .navigationTitle("今日打卡")
            .task(id: todayPlan?.persistentModelID) {
                refreshTodaySessions()
            }
        }
    }
    
    private func refreshTodaySessions() {
        guard let plan = todayPlan else {
            WidgetSyncManager.sync(workoutDays: workoutDays, context: modelContext)
            return
        }
        for exercise in plan.exercises {
            exercise.prepareForTodayIfNeeded()
        }
        if !plan.isRestDay && !plan.exercises.isEmpty {
            todaySession = WorkoutHistoryManager.getOrCreateTodaySession(context: modelContext, plan: plan)
            WorkoutHistoryManager.syncSessionMetadata(session: todaySession!, plan: plan)
        }
        syncWidgetAndSave()
    }
}

extension TodayWorkoutView {
    
    private func workoutListView(plan: WorkoutDay) -> some View {
        VStack(spacing: 10) {
            progressHeader(plan: plan)
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 12) {
                    if let session = todaySession {
                        ForEach(plan.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                            ExpandableExerciseRow(
                                exercise: exercise,
                                session: session,
                                isExpanded: expandedExerciseID == exercise.persistentModelID,
                                onToggleExpand: {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)) {
                                        if expandedExerciseID == exercise.persistentModelID {
                                            expandedExerciseID = nil
                                        } else {
                                            expandedExerciseID = exercise.persistentModelID
                                        }
                                    }
                                },
                                onSetProgressChanged: {
                                    handleSetProgressChanged(plan: plan)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func progressHeader(plan: WorkoutDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("训练进度")
                    .font(.headline)
                Text("\(completedSetCount) / \(totalSetCount) 组")
                    .font(.title2.bold())
                    .foregroundColor(.accentColor)
                Text("\(completedExerciseCount) / \(plan.exercises.count) 个动作已完成")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            RingProgressView(progress: progress, size: 60)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func handleSetProgressChanged(plan: WorkoutDay) {
        for exercise in plan.exercises {
            exercise.prepareForTodayIfNeeded()
        }
        
        if todaySession == nil {
            todaySession = WorkoutHistoryManager.getOrCreateTodaySession(context: modelContext, plan: plan)
        }
        if let session = todaySession {
            WorkoutHistoryManager.syncSessionMetadata(session: session, plan: plan)
        }
        
        let allExercisesDone = completedExerciseCount == plan.exercises.count && !plan.exercises.isEmpty
        if allExercisesDone && !didCelebrateFullWorkout {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            didCelebrateFullWorkout = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showCompletionSummary = true
            }
        } else if !allExercisesDone {
            didCelebrateFullWorkout = false
        }
        
        syncWidgetAndSave()
    }
    
    private func syncWidgetAndSave() {
        WidgetSyncManager.sync(workoutDays: workoutDays, context: modelContext)
        try? modelContext.save()
    }
    
    private var restDayView: some View {
        VStack(spacing: 20) {
            Image(systemName: "battery.100")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .symbolEffect(.pulse)
            Text("今天是休息日")
                .font(.title2.bold())
            Text("肌肉正在修复，好好放松一下吧！")
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyPlanView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("今日无训练安排")
                .font(.title2.bold())
            Text("去「计划」页面添加一些动作吧")
                .foregroundColor(.secondary)
        }
    }
}
