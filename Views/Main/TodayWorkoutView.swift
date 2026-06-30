//
//  TodayWorkoutView.swift
//  FitnessApp
//
//  Redesigned in the Tiimo aesthetic: serif day header, counter pill, soft
//  progress card, and emoji-tiled exercise cards. All SwiftData logic is
//  unchanged from the original — only the presentation layer was restyled.
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
                Theme.Color.background.ignoresSafeArea()

                if let plan = todayPlan {
                    if plan.isRestDay {
                        restDayView
                    } else if plan.exercises.isEmpty {
                        emptyPlanView
                    } else {
                        workoutListView(plan: plan)
                    }
                } else {
                    Text("未找到计划").foregroundStyle(Theme.Color.textSecondary)
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
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: Header

    private func dayHeader(plan: WorkoutDay) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            HStack {
                CounterPill(emoji: "🎉", value: completedExerciseCount, total: plan.exercises.count)
                Spacer()
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text(plan.dayName)
                    .font(.displayLarge)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(Date.now, format: .dateTime.month(.wide).day().year())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.s)
    }

    private func workoutListView(plan: WorkoutDay) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            dayHeader(plan: plan)
            progressCard(plan: plan)
                .padding(.horizontal, Theme.Spacing.xl)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.m) {
                    SectionPill(
                        title: "今日训练",
                        count: plan.exercises.count,
                        systemImage: "dumbbell.fill",
                        tint: Theme.Color.tintPeach
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    private func progressCard(plan: WorkoutDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("训练进度")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
                Text("\(completedSetCount) / \(totalSetCount) 组")
                    .font(.display(28, weight: .bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("\(completedExerciseCount) / \(plan.exercises.count) 个动作已完成")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            RingProgressView(progress: progress, size: 64)
        }
        .tiimoCard()
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

    // MARK: Empty / rest states

    private var restDayView: some View {
        VStack(spacing: Theme.Spacing.l) {
            EmojiTile(emoji: "🔋", tint: Theme.Color.tintMint, size: 72)
            Text("今天是休息日")
                .font(.displayMedium)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("肌肉正在修复，好好放松一下吧！")
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.xl)
    }

    private var emptyPlanView: some View {
        VStack(spacing: Theme.Spacing.l) {
            EmojiTile(emoji: "📋", tint: Theme.Color.surfaceMuted, size: 72)
            Text("今日无训练安排")
                .font(.displayMedium)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("去「计划」页面添加一些动作吧")
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.xl)
    }
}
