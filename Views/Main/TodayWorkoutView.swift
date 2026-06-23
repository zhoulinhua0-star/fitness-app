//
//  TodayWorkoutView.swift
//  FitnessApp
//

import SwiftUI
import SwiftData
import WidgetKit

struct TodayWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutDays: [WorkoutDay]
    @State private var expandedExerciseID: PersistentIdentifier?
    @State private var didCelebrateFullWorkout = false
    @State private var showCompletionSummary = false
    @State private var todaySession: WorkoutSession?
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    var todayPlan: WorkoutDay? {
        let todayString = Self.weekdayFormatter
            .string(from: Date())
            .replacingOccurrences(of: "星期", with: "周")
        return workoutDays.first(where: { $0.dayName == todayString })
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
                
                if showCompletionSummary, let session = todaySession, let plan = todayPlan {
                    WorkoutCompletionSummaryView(
                        completedSets: completedSetCount,
                        totalSets: totalSetCount,
                        completedExercises: completedExerciseCount,
                        totalExercises: plan.exercises.count,
                        duration: Date().timeIntervalSince(session.startedAt),
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
            .onAppear {
                refreshTodaySessions()
            }
        }
    }
    
    private func refreshTodaySessions() {
        guard let plan = todayPlan else { return }
        for exercise in plan.exercises {
            exercise.prepareForTodayIfNeeded()
        }
        if !plan.isRestDay && !plan.exercises.isEmpty {
            todaySession = WorkoutHistoryManager.getOrCreateTodaySession(context: modelContext, plan: plan)
            WorkoutHistoryManager.syncSessionMetadata(session: todaySession!, plan: plan)
        }
        syncWidgetAndSave(plan: plan)
    }
}

extension TodayWorkoutView {
    
    private func workoutListView(plan: WorkoutDay) -> some View {
        VStack(spacing: 10) {
            progressHeader(plan: plan)
                .padding(.top)
            
            List {
                ForEach(plan.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                    if let session = todaySession {
                        ExpandableExerciseRow(
                            exercise: exercise,
                            session: session,
                            isExpanded: expandedExerciseID == exercise.persistentModelID,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !exercise.isFullyCompletedToday {
                                Button {
                                    completeNextSetViaSwipe(exercise: exercise, plan: plan)
                                } label: {
                                    Label("完成一组", systemImage: "checkmark")
                                }
                                .tint(.accentColor)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal)
        }
    }
    
    private func completeNextSetViaSwipe(exercise: Exercise, plan: WorkoutDay) {
        guard let session = todaySession else { return }
        let nextSetIndex = exercise.effectiveCompletedSetCount + 1
        guard exercise.completeNextSet() else { return }
        
        WorkoutHistoryManager.logSet(
            context: modelContext,
            session: session,
            exercise: exercise,
            setIndex: nextSetIndex,
            weight: nil
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        handleSetProgressChanged(plan: plan)
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
        withAnimation {
            for exercise in plan.exercises {
                exercise.prepareForTodayIfNeeded()
            }
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
        
        syncWidgetAndSave(plan: plan)
    }
    
    private func syncWidgetAndSave(plan: WorkoutDay?) {
        if let plan, !plan.isRestDay {
            WidgetDataStore.updateTodayProgress(
                completedSets: completedSetCount,
                totalSets: totalSetCount,
                completedExercises: completedExerciseCount,
                totalExercises: plan.exercises.count,
                dayName: plan.dayName
            )
            WidgetCenter.shared.reloadAllTimelines()
        }
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
