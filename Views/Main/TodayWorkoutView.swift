//
//  TodayWorkoutView.swift
//  FitnessApp
//
//  Redesigned in the Tiimo aesthetic: serif day header, counter pill, soft
//  progress card, and emoji-tiled exercise cards.
//
//  This is the app's single logging surface. It renders either the weekly
//  plan for today OR an ad-hoc "即兴" workout (exercises injected from the
//  Plan tab's improv builder) through the exact same UI — there is no longer
//  a separate improv session screen.
//

import SwiftUI
import SwiftData

struct TodayWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var workoutDays: [WorkoutDay]
    @Query(filter: #Predicate<Exercise> { $0.isImprov }) private var improvExercises: [Exercise]
    @AppStorage("expandedExerciseName") private var expandedExerciseName: String = ""
    /// Start-of-day timestamp of the day the user finished an improv workout.
    /// While it matches today, the plan stays hidden behind a "day complete"
    /// card; it self-expires at midnight (tomorrow's startOfDay ≠ stamp).
    @AppStorage("improvFinishedDayStamp") private var improvFinishedDayStamp: Double = 0
    @State private var didCelebrateFullWorkout = false
    @State private var showCompletionSummary = false
    @State private var showImprovEditor = false
    @State private var todaySession: WorkoutSession?
    @State private var navigation = AppNavigation.shared

    var todayPlan: WorkoutDay? {
        let todayString = WorkoutHistoryManager.todayWeekdayString()
        return workoutDays.first { $0.dayName == todayString }
    }

    // MARK: Active workout (plan or improv)

    /// Ad-hoc improv exercises created today. They live only for today and are
    /// purged on the next day (see `purgeStaleImprovExercises`).
    var todayImprovExercises: [Exercise] {
        improvExercises
            .filter { $0.sessionDate.map { Calendar.current.isDateInToday($0) } ?? false }
            .sorted { $0.order < $1.order }
    }

    /// When true, today is being freestyled — improv takes over the view and
    /// the weekly plan (untouched) simply returns tomorrow.
    var isImprovActive: Bool { !todayImprovExercises.isEmpty }

    /// True after 「结束即兴」 on a day where sets were logged: training is
    /// done for today, so the plan stays hidden until tomorrow.
    var isDayFinishedToday: Bool {
        improvFinishedDayStamp == WorkoutHistoryManager.startOfDay().timeIntervalSince1970
    }

    /// The exercises actually shown & logged today, whatever the source.
    var activeExercises: [Exercise] {
        isImprovActive
            ? todayImprovExercises.filter { !$0.isRemovedFromImprov }
            : (todayPlan?.exercises.sorted { $0.order < $1.order } ?? [])
    }

    /// Includes removed improv exercises until the session ends, allowing their
    /// completed sets to remain in today's progress and history.
    var sessionExercises: [Exercise] {
        isImprovActive ? todayImprovExercises : activeExercises
    }

    /// Removed exercises count only when the user completed at least one set.
    var countedExercises: [Exercise] {
        sessionExercises.filter {
            !$0.isRemovedFromImprov || $0.effectiveCompletedSetCount > 0
        }
    }

    var headerDayName: String {
        isImprovActive ? "即兴训练" : (todayPlan?.dayName ?? "")
    }

    var completedExerciseCount: Int {
        countedExercises.filter {
            $0.isRemovedFromImprov || $0.isFullyCompletedToday
        }.count
    }

    var totalExerciseCount: Int {
        countedExercises.count
    }

    var completedSetCount: Int {
        WorkoutHistoryManager.completedSetCount(for: sessionExercises)
    }

    var totalSetCount: Int {
        WorkoutHistoryManager.plannedSetCount(for: sessionExercises)
    }

    var progress: Double {
        guard totalSetCount > 0 else { return 0 }
        return Double(completedSetCount) / Double(totalSetCount)
    }

    /// Re-runs session setup whenever the active workout meaningfully changes
    /// (day rollover, plan edits, or improv exercises being injected/cleared).
    private var refreshKey: String {
        "\(headerDayName)#\(activeExercises.count)#\(totalSetCount)#\(isImprovActive)#\(isDayFinishedToday)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                if isImprovActive {
                    workoutListView
                } else if isDayFinishedToday {
                    dayCompletedView
                } else if let plan = todayPlan {
                    if plan.isRestDay {
                        restDayView
                    } else if plan.exercises.isEmpty {
                        emptyPlanView
                    } else {
                        workoutListView
                    }
                } else {
                    Text("未找到计划").foregroundStyle(Theme.Color.textSecondary)
                }

                if showCompletionSummary {
                    WorkoutCompletionSummaryView(
                        completedSets: completedSetCount,
                        totalSets: totalSetCount,
                        completedExercises: completedExerciseCount,
                        totalExercises: totalExerciseCount,
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
            .task(id: refreshKey) {
                refreshTodaySessions()
                openPendingRestTimerIfNeeded()
            }
            .onChange(of: navigation.pendingRestTimerID) { _, _ in
                openPendingRestTimerIfNeeded()
            }
            .sheet(isPresented: $showImprovEditor) {
                ImprovWorkoutEditorSheet(onWorkoutChanged: handleImprovWorkoutChanged)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func refreshTodaySessions() {
        purgeStaleImprovExercises()

        // Training is done for today (improv finished): leave today's stored
        // session untouched — re-syncing here would overwrite its "即兴训练"
        // name and logged counts with the plan's zero-progress numbers.
        guard !isDayFinishedToday else {
            try? modelContext.save()
            return
        }

        let exercises = sessionExercises
        for exercise in exercises {
            exercise.prepareForTodayIfNeeded()
        }
        if !exercises.isEmpty {
            let session = WorkoutHistoryManager.getOrCreateTodaySession(
                context: modelContext,
                dayName: headerDayName,
                exercises: exercises
            )
            todaySession = session
            WorkoutHistoryManager.syncSessionMetadata(session: session, dayName: headerDayName, exercises: exercises)
        }
        syncWidgetAndSave()
    }

    private func openPendingRestTimerIfNeeded() {
        guard let timerID = navigation.pendingRestTimerID else { return }
        guard let exercise = activeExercises.first(where: {
            RestTimerCoordinator.timerID(for: $0.persistentModelID) == timerID
        }) else {
            navigation.pendingRestTimerID = nil
            return
        }

        expandedExerciseName = exercise.name
        navigation.pendingRestTimerID = nil
    }

    /// Delete improv exercises left over from previous days so they never
    /// resurface (they are not part of any persistent plan).
    private func purgeStaleImprovExercises() {
        let stale = improvExercises.filter {
            !($0.sessionDate.map { Calendar.current.isDateInToday($0) } ?? false)
        }
        for exercise in stale {
            RestTimerCoordinator.shared.cancel(
                timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
            )
            modelContext.delete(exercise)
        }
    }
}

extension TodayWorkoutView {

    // MARK: Header

    private var dayHeader: some View {
        VStack(spacing: Theme.Spacing.l) {
            headerActions

            VStack(spacing: Theme.Spacing.xs) {
                Text(headerDayName)
                    .appScaledFont(size: 34, relativeTo: .largeTitle, weight: .bold, design: .serif)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(Date.now, format: .dateTime.month(.wide).day().year())
                    .appScaledFont(size: 15, relativeTo: .subheadline, weight: .medium)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.s)
    }

    @ViewBuilder
    private var headerActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                workoutCounter
                if isImprovActive {
                    endImprovButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                workoutCounter
                Spacer()
                if isImprovActive {
                    endImprovButton
                }
            }
        }
    }

    private var workoutCounter: some View {
        CounterPill(
            emoji: isImprovActive ? "⚡️" : "🎉",
            value: completedExerciseCount,
            total: totalExerciseCount
        )
    }

    private var endImprovButton: some View {
        Button(action: exitImprov) {
            Label("结束即兴", systemImage: "xmark.circle.fill")
                .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 44)
                .background(Theme.Color.surfaceMuted, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var workoutListView: some View {
        VStack(spacing: Theme.Spacing.l) {
            dayHeader
            progressCard
                .padding(.horizontal, Theme.Spacing.xl)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.m) {
                    HStack(spacing: Theme.Spacing.m) {
                        SectionPill(
                            title: isImprovActive ? "即兴训练" : "今日训练",
                            count: activeExercises.count,
                            systemImage: "dumbbell.fill",
                            tint: Theme.Color.tintPeach
                        )

                        Spacer()

                        if isImprovActive {
                            Button {
                                showImprovEditor = true
                            } label: {
                                Label("编辑", systemImage: "slider.horizontal.3")
                                    .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
                                    .foregroundStyle(Theme.Color.accent)
                                    .padding(.horizontal, Theme.Spacing.m)
                                    .frame(minHeight: 44)
                                    .background(Theme.Color.accentSoft, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("添加、移出或调整即兴训练动作顺序")
                        }
                    }

                    if isImprovActive && activeExercises.isEmpty {
                        improvEmptyState
                    } else if let session = todaySession {
                        ForEach(activeExercises) { exercise in
                            ExpandableExerciseRow(
                                exercise: exercise,
                                session: session,
                                isExpanded: expandedExerciseName == exercise.name,
                                onToggleExpand: {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)) {
                                        expandedExerciseName = expandedExerciseName == exercise.name ? "" : exercise.name
                                    }
                                },
                                onSetProgressChanged: {
                                    handleSetProgressChanged()
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

    private var progressCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    progressSummary
                    RingProgressView(progress: progress, size: 64)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    progressSummary
                    Spacer()
                    RingProgressView(progress: progress, size: 64)
                }
            }
        }
        .tiimoCard()
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("训练进度")
                .appScaledFont(size: 14, relativeTo: .subheadline, weight: .semibold)
                .foregroundStyle(Theme.Color.textSecondary)
            Text("\(completedSetCount) / \(totalSetCount) 组")
                .appScaledFont(size: 28, relativeTo: .title, weight: .bold, design: .serif)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("\(completedExerciseCount) / \(totalExerciseCount) 个动作已完成")
                .font(.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private func handleSetProgressChanged() {
        let exercises = sessionExercises
        for exercise in exercises {
            exercise.prepareForTodayIfNeeded()
        }

        if todaySession == nil {
            todaySession = WorkoutHistoryManager.getOrCreateTodaySession(
                context: modelContext,
                dayName: headerDayName,
                exercises: exercises
            )
        }
        if let session = todaySession {
            WorkoutHistoryManager.syncSessionMetadata(session: session, dayName: headerDayName, exercises: exercises)
        }

        let allExercisesDone = completedExerciseCount == totalExerciseCount && totalExerciseCount > 0
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

    private func handleImprovWorkoutChanged() {
        if !activeExercises.contains(where: { $0.name == expandedExerciseName }) {
            expandedExerciseName = ""
        }
        didCelebrateFullWorkout = false
        showCompletionSummary = false
        syncWidgetAndSave()
    }

    /// End the improv session. If any sets were logged, today counts as
    /// trained: the session record is frozen as "即兴训练" and the plan stays
    /// hidden behind `dayCompletedView` until tomorrow. If nothing was
    /// logged, this is just backing out — the plan reappears as before.
    private func exitImprov() {
        let trainedToday = completedSetCount > 0

        if trainedToday, let session = todaySession {
            // Freeze the improv record before the exercises are deleted —
            // afterwards `refreshTodaySessions` skips syncing entirely.
            WorkoutHistoryManager.syncSessionMetadata(
                session: session,
                dayName: "即兴训练",
                exercises: todayImprovExercises
            )
            improvFinishedDayStamp = WorkoutHistoryManager.startOfDay().timeIntervalSince1970
        }

        for exercise in todayImprovExercises {
            RestTimerCoordinator.shared.cancel(
                timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
            )
            modelContext.delete(exercise)
        }
        expandedExerciseName = ""
        didCelebrateFullWorkout = false
        showCompletionSummary = false
        try? modelContext.save()

        if trainedToday {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    private func syncWidgetAndSave() {
        WidgetSyncManager.sync(workoutDays: workoutDays, context: modelContext)
        try? modelContext.save()
    }

    private var improvEmptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "plus.circle")
                .appScaledFont(size: 30, relativeTo: .title, weight: .medium)
                .foregroundStyle(Theme.Color.accent)
            Text("暂时没有待训练动作")
                .appScaledFont(size: 16, relativeTo: .headline, weight: .semibold)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("打开编辑面板添加动作，或结束本次即兴训练")
                .font(.subheadline)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showImprovEditor = true
            } label: {
                Label("添加动作", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Color.accent)
        }
        .frame(maxWidth: .infinity)
        .tiimoCard(padding: Theme.Spacing.xl)
    }

    // MARK: Day completed (improv finished)

    /// Shown for the rest of the day after 「结束即兴」: a summary of the
    /// finished improv session instead of the (already-trained-past) plan,
    /// with a small escape hatch for the rare second workout.
    private var dayCompletedView: some View {
        let session = WorkoutHistoryManager.fetchTodaySession(context: modelContext)
        let setCount = session?.completedSetCount ?? 0
        let exerciseCount = Set((session?.setLogs ?? []).map(\.exerciseName)).count

        return VStack(spacing: Theme.Spacing.l) {
            EmojiTile(emoji: "✅", tint: Theme.Color.tintMint, size: 72)
            Text("今日训练已完成")
                .appScaledFont(size: 24, relativeTo: .title2, weight: .bold, design: .serif)
                .foregroundStyle(Theme.Color.textPrimary)
            VStack(spacing: Theme.Spacing.xs) {
                Text("即兴训练 · \(exerciseCount) 个动作 · \(setCount) 组")
                    .appScaledFont(size: 15, relativeTo: .subheadline, weight: .semibold)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("练得不错，好好休息，明天见！")
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            Button(action: resumeTodayPlan) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("继续今日计划")
                }
                .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .background(Theme.Color.surfaceMuted, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Spacing.m)
        }
        .padding(Theme.Spacing.xl)
    }

    /// Opt back into today's plan for a second workout — clears the stamp;
    /// the `.task(id: refreshKey)` then restores the normal plan flow.
    private func resumeTodayPlan() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            improvFinishedDayStamp = 0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Empty / rest states

    private var restDayView: some View {
        VStack(spacing: Theme.Spacing.l) {
            EmojiTile(emoji: "🔋", tint: Theme.Color.tintMint, size: 72)
            Text("今天是休息日")
                .appScaledFont(size: 24, relativeTo: .title2, weight: .bold, design: .serif)
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
                .appScaledFont(size: 24, relativeTo: .title2, weight: .bold, design: .serif)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("去「计划」页面添加一些动作吧")
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.xl)
    }
}
