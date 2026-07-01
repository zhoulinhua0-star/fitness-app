//
//  PlanSetupView.swift
//  FitnessApp
//
//  Restyled with the Tiimo Theme system. All SwiftData logic, calendar sync,
//  copy/clear/move/delete, and initialization are preserved exactly.
//

import SwiftUI
import SwiftData

private enum PlanMode: String, CaseIterable {
    case plan  = "计划模式"
    case improv = "即兴模式"

    var icon: String {
        switch self {
        case .plan:   return "calendar"
        case .improv: return "bolt.fill"
        }
    }
}

// A Tiimo-style pill segmented control used to switch between modes.
private struct PlanModeToggle: View {
    @Binding var mode: PlanMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PlanMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { mode = m }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(m.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(mode == m ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        mode == m
                            ? Theme.Color.surface
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(
                        color: mode == m ? Theme.Shadow.color : .clear,
                        radius: 6, y: 2
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.Color.surfaceMuted,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct PlanSetupView: View {
    /// Switches the app to the "今日" tab (used after starting an improv workout).
    var onSwitchToToday: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query private var workoutDays: [WorkoutDay]

    @State private var isSyncing = false
    @State private var showSuccessFeedback = false
    @State private var planMode: PlanMode = .plan
    @State private var shimmerX: CGFloat = -0.6

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.m), GridItem(.flexible(), spacing: Theme.Spacing.m)]

    var sortedDays: [WorkoutDay] {
        let order = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return workoutDays.sorted {
            (order.firstIndex(of: $0.dayName) ?? 0) < (order.firstIndex(of: $1.dayName) ?? 0)
        }
    }

    private var weekOverview: WeekPlanSummary.Overview {
        let snapshots = sortedDays.map { day in
            WeekPlanSummary.DaySnapshot(
                dayName: day.dayName,
                isRestDay: day.isRestDay,
                totalSets: day.exercises.reduce(0) { $0 + $1.sets },
                exerciseNames: day.exercises.sorted { $0.order < $1.order }.map(\.name)
            )
        }
        return WeekPlanSummary.buildOverview(from: snapshots)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.Color.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Page header + mode toggle
                        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                            pageHeader
                            PlanModeToggle(mode: $planMode)
                                .padding(.horizontal, Theme.Spacing.xl)
                        }

                        // Mode content
                        switch planMode {
                        case .plan:
                            planContent
                        case .improv:
                            ImprovModeView(onStartWorkout: onSwitchToToday)
                                .padding(.top, Theme.Spacing.xs)
                        }
                    }
                    .padding(.bottom, Theme.Spacing.xxl)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: planMode)
                }

                // Calendar sync only visible in plan mode
                if planMode == .plan {
                    calendarSyncButton
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.l)
                        .background(
                            LinearGradient(
                                colors: [Theme.Color.background.opacity(0), Theme.Color.background],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 100)
                            .allowsHitTesting(false),
                            alignment: .bottom
                        )
                        .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                revertEnglishDayNamesIfNeeded()
                initializeDefaultDataIfNeeded()
                WidgetSyncManager.sync(workoutDays: sortedDays, context: modelContext)
            }
        }
    }

    // MARK: Plan mode content

    @ViewBuilder
    private var planContent: some View {
        if sortedDays.isEmpty {
            ProgressView("正在初始化课表...").padding(.top, 40)
        } else {
            WeeklyPlanOverview(overview: weekOverview)
                .padding(.horizontal, Theme.Spacing.xl)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                ForEach(sortedDays) { day in
                    NavigationLink(destination: DayDetailEditorView(workoutDay: day)) {
                        PlanDayCard(workoutDay: day)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Color.clear.frame(height: 80)
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("健身课表")
                .font(.displayLarge)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(planMode == .plan ? "管理每周训练计划" : "随心所欲，今天练啥？")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)
                .animation(.easeInOut(duration: 0.25), value: planMode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.s)
    }

    private var calendarSyncButton: some View {
        Button(action: syncToCalendar) {
            HStack(spacing: Theme.Spacing.m) {
                if isSyncing {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.Color.ctaLabel))
                    Text("Syncing...")
                } else if showSuccessFeedback {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Synced!")
                } else {
                    Image(systemName: "calendar.badge.plus")
                    Text("Sync to Calendar")
                }
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(showSuccessFeedback ? .white : Theme.Color.ctaLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if showSuccessFeedback {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x06B6D4), Color(hex: 0x8B5CF6), Color(hex: 0xEC4899)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .overlay(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [.clear, .white.opacity(0.38), .clear],
                                    startPoint: .init(x: shimmerX, y: 0.5),
                                    endPoint: .init(x: shimmerX + 0.6, y: 0.5)
                                ))
                        )
                } else {
                    Capsule().fill(Theme.Color.cta)
                }
            }
            .scaleEffect(showSuccessFeedback ? 1.03 : 1.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.65), value: showSuccessFeedback)
        }
        .buttonStyle(.plain)
        .disabled(isSyncing || showSuccessFeedback)
        .onChange(of: showSuccessFeedback) { _, isSuccess in
            if isSuccess {
                shimmerX = -0.6
                withAnimation(.easeInOut(duration: 0.9).delay(0.15)) {
                    shimmerX = 1.2
                }
            }
        }
    }
}

// MARK: - Plan Day Card

struct PlanDayCard: View {
    let workoutDay: WorkoutDay

    private var isToday: Bool {
        workoutDay.dayName == WeekPlanSummary.todayDayName()
    }

    private var totalSets: Int {
        workoutDay.exercises.reduce(0) { $0 + $1.sets }
    }

    private var intensityEmoji: String {
        if workoutDay.isRestDay { return "🛋️" }
        if workoutDay.exercises.isEmpty { return "📋" }
        if totalSets < 12 { return "💧" }
        if totalSets <= 20 { return "🔥" }
        return "💀"
    }

    private var intensityLabel: String {
        if totalSets < 12 { return "适中" }
        if totalSets <= 20 { return "高燃" }
        return "极限"
    }

    private var intensityColor: Color {
        if totalSets < 12 { return Theme.Color.tintBlue }
        if totalSets <= 20 { return Theme.Color.tintPeach }
        return Color.red.opacity(0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(WeekdayDisplay.label(for: workoutDay.dayName))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isToday ? Theme.Color.accent : Theme.Color.textPrimary)
                Spacer()
                if workoutDay.isRestDay {
                    Text("休息")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Color.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Color.tintMint, in: Capsule())
                } else if isToday {
                    Text("今天")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Color.accentSoft, in: Capsule())
                }
            }

            Divider().background(Theme.Color.hairline)

            if workoutDay.isRestDay {
                VStack(spacing: Theme.Spacing.xs) {
                    Image("RestDayIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.red.opacity(0.25), radius: 4, y: 2)
                    Text("充电恢复中")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workoutDay.exercises.isEmpty {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("📋").font(.system(size: 28))
                    Text("点击去添加")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(workoutDay.exercises.sorted(by: { $0.order < $1.order }).prefix(2)) { exercise in
                        HStack {
                            Text("• \(exercise.name)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Color.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(exercise.sets)组")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                    if workoutDay.exercises.count > 2 {
                        Text("等共 \(workoutDay.exercises.count) 个动作")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                HStack {
                    Text("\(intensityEmoji) \(intensityLabel)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(intensityColor, in: Capsule())
                    Spacer()
                    Text("\(totalSets) 组")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(height: 165)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(isToday ? Theme.Color.accent : Theme.Color.hairline,
                        lineWidth: isToday ? 1.5 : 1)
        )
        .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
    }
}

// MARK: - Day detail editor (fully custom Tiimo-style layout)

struct DayDetailEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutDay: WorkoutDay
    @Query private var allDays: [WorkoutDay]

    @State private var newExerciseName = ""
    @State private var newSets = 4
    @State private var newReps = 12
    @FocusState private var nameFieldFocused: Bool

    /// Common lifts offered as quick-pick chips in the composer.
    private let quickPicks = ["卧推", "深蹲", "硬拉", "引体向上", "肩上推举", "杠铃划船", "二头弯举", "平板支撑"]

    private var sortedExercises: [Exercise] {
        workoutDay.exercises.sorted(by: { $0.order < $1.order })
    }

    var totalSets: Int { workoutDay.exercises.reduce(0) { $0 + $1.sets } }
    var totalReps: Int { workoutDay.exercises.reduce(0) { $0 + $1.sets * $1.reps } }

    /// Rough session estimate: each set ≈ working time (reps×3s) + one rest.
    private var estimatedMinutes: Int {
        let rest = AppSettings.shared.defaultRestSeconds
        let seconds = workoutDay.exercises.reduce(0) { acc, ex in
            acc + ex.sets * (ex.reps * 3 + rest)
        }
        return max(1, Int((Double(seconds) / 60).rounded()))
    }

    var copyableDays: [WorkoutDay] {
        let order = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return allDays
            .filter { $0.dayName != workoutDay.dayName && !$0.isRestDay && !$0.exercises.isEmpty }
            .sorted { (order.firstIndex(of: $0.dayName) ?? 0) < (order.firstIndex(of: $1.dayName) ?? 0) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xl) {
                restDayToggleCard

                if !workoutDay.isRestDay {
                    if !workoutDay.exercises.isEmpty {
                        summaryCard
                    }
                    exercisesSection
                    composerSection
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xxl)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: workoutDay.isRestDay)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: workoutDay.exercises.count)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("\(workoutDay.dayName) 安排")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !workoutDay.isRestDay && !workoutDay.exercises.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: clearAllExercises) {
                            Label("清空今日动作", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.Color.accent)
                    }
                }
            }
        }
    }

    // MARK: Rest day toggle

    private var restDayToggleCard: some View {
        HStack(spacing: Theme.Spacing.m) {
            EmojiTile(emoji: workoutDay.isRestDay ? "🛋️" : "💪",
                      tint: workoutDay.isRestDay ? Theme.Color.tintMint : Theme.Color.accentSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutDay.isRestDay ? "休息日" : "训练日")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(workoutDay.isRestDay ? "肌肉正在修复，好好放松" : "安排今天的训练动作")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $workoutDay.isRestDay)
                .labelsHidden()
                .tint(Theme.Color.success)
        }
        .tiimoCard()
    }

    // MARK: Summary

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryStat(value: "\(workoutDay.exercises.count)", label: "动作", unit: "个")
            divider
            summaryStat(value: "\(totalSets)", label: "总组数", unit: "组")
            divider
            summaryStat(value: "~\(estimatedMinutes)", label: "预计时长", unit: "分")
        }
        .tiimoCard(padding: Theme.Spacing.l)
    }

    private var divider: some View {
        Divider().frame(height: 40).background(Theme.Color.hairline)
    }

    private func summaryStat(value: String, label: String, unit: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.display(24, weight: .bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "已编排动作", count: workoutDay.exercises.count,
                        systemImage: "dumbbell.fill", tint: Theme.Color.tintPeach)

            if workoutDay.exercises.isEmpty {
                emptyExercisesCard
            } else {
                ForEach(Array(sortedExercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                    ExerciseEditorCard(
                        exercise: exercise,
                        canMoveUp: index > 0,
                        canMoveDown: index < sortedExercises.count - 1,
                        onMoveUp: { moveExercise(at: index, by: -1) },
                        onMoveDown: { moveExercise(at: index, by: 1) },
                        onDelete: { deleteExercise(exercise) }
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
        }
    }

    private var emptyExercisesCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("🗒️").font(.system(size: 36))
            Text("还没有安排动作")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)

            if !copyableDays.isEmpty {
                Menu {
                    ForEach(copyableDays) { sourceDay in
                        Button("复制 \(sourceDay.dayName) 的课表") { copyExercises(from: sourceDay) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("从其他日期复制课表")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(Theme.Color.accentSoft, in: Capsule())
                }
            } else {
                Text("在下方添加你的第一个动作")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.s)
        .tiimoCard(padding: Theme.Spacing.xl)
    }

    // MARK: Composer

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "添加新动作", systemImage: "plus.circle.fill", tint: Theme.Color.tintBlue)

            VStack(spacing: Theme.Spacing.l) {
                TextField("", text: $newExerciseName, prompt: Text("输入动作名称").foregroundColor(Theme.Color.textSecondary))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(addExercise)
                    .themedField()

                // Quick-pick chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(quickPicks, id: \.self) { pick in
                            Button {
                                newExerciseName = pick
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(pick)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(newExerciseName == pick ? Theme.Color.accent : Theme.Color.textSecondary)
                                    .padding(.horizontal, Theme.Spacing.m)
                                    .padding(.vertical, Theme.Spacing.s)
                                    .background(
                                        newExerciseName == pick ? Theme.Color.accentSoft : Theme.Color.surfaceMuted,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                HStack(spacing: Theme.Spacing.xl) {
                    ThemedStepper(title: "训练组数", value: $newSets, range: 1...10)
                    ThemedStepper(title: "每组次数", value: $newReps, range: 1...99)
                    Spacer()
                }

                Button(action: addExercise) {
                    Label("添加动作", systemImage: "plus")
                }
                .buttonStyle(.primaryCTA)
                .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .tiimoCard()
        }
    }

    // MARK: Actions

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            workoutDay.exercises.append(Exercise(name: trimmed, sets: newSets, reps: newReps, order: workoutDay.exercises.count))
        }
        newExerciseName = ""
        nameFieldFocused = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func deleteExercise(_ exercise: Exercise) {
        withAnimation {
            workoutDay.exercises.removeAll { $0.id == exercise.id }
            // Re-pack order indices so they stay contiguous.
            for (index, ex) in workoutDay.exercises.sorted(by: { $0.order < $1.order }).enumerated() {
                ex.order = index
            }
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func moveExercise(at index: Int, by offset: Int) {
        var list = sortedExercises
        let target = index + offset
        guard list.indices.contains(index), list.indices.contains(target) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            list.swapAt(index, target)
            for (i, ex) in list.enumerated() { ex.order = i }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func copyExercises(from sourceDay: WorkoutDay) {
        let sorted = sourceDay.exercises.sorted(by: { $0.order < $1.order })
        withAnimation {
            for (index, ex) in sorted.enumerated() {
                workoutDay.exercises.append(Exercise(name: ex.name, sets: ex.sets, reps: ex.reps, order: index))
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func clearAllExercises() {
        withAnimation { workoutDay.exercises.removeAll() }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Exercise editor card

struct ExerciseEditorCard: View {
    @Bindable var exercise: Exercise
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                EmojiTile(emoji: ExerciseEmoji.forName(exercise.name))

                TextField("动作名称", text: $exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)

                Menu {
                    if canMoveUp { Button { onMoveUp() } label: { Label("上移", systemImage: "arrow.up") } }
                    if canMoveDown { Button { onMoveDown() } label: { Label("下移", systemImage: "arrow.down") } }
                    Button(role: .destructive, action: onDelete) { Label("删除动作", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Color.surfaceMuted, in: Circle())
                }
            }

            Divider().background(Theme.Color.hairline)

            HStack(spacing: Theme.Spacing.xl) {
                ThemedStepper(title: "组数", value: $exercise.sets, range: 1...20)
                ThemedStepper(title: "次数", value: $exercise.reps, range: 1...100)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("总计")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("\(exercise.sets * exercise.reps) 次")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
        .tiimoCard()
    }
}

// MARK: - PlanSetupView logic extension

extension PlanSetupView {
    private func syncToCalendar() {
        isSyncing = true
        Task {
            let success = await CalendarManager.shared.requestAccessAndSync(workoutDays: sortedDays)
            await MainActor.run {
                isSyncing = false
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showSuccessFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.3)) { showSuccessFeedback = false }
                    }
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }
    }

    private static let englishToChineseNames: [String: String] = [
        "Mon": "周一", "Tue": "周二", "Wed": "周三", "Thu": "周四",
        "Fri": "周五", "Sat": "周六", "Sun": "周日"
    ]

    private func revertEnglishDayNamesIfNeeded() {
        var changed = false
        for day in workoutDays {
            if let chinese = Self.englishToChineseNames[day.dayName] { day.dayName = chinese; changed = true }
        }
        if changed, let sessions = try? modelContext.fetch(FetchDescriptor<WorkoutSession>()) {
            for session in sessions {
                if let chinese = Self.englishToChineseNames[session.dayName] { session.dayName = chinese }
            }
            try? modelContext.save()
        }
    }

    private func initializeDefaultDataIfNeeded() {
        guard workoutDays.isEmpty else { return }
        for dayName in ["周一", "周二", "周三", "周四", "周五", "周六", "周日"] {
            modelContext.insert(WorkoutDay(dayName: dayName, isRestDay: dayName == "周日"))
        }
        try? modelContext.save()
    }
}
