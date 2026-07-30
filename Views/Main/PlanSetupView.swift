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

private enum CalendarSyncIssue: Hashable, Identifiable {
    case permissionDenied
    case restricted
    case failed

    var id: Self { self }

    var title: String {
        switch self {
        case .permissionDenied: AppLocalization.string("日历权限未开启")
        case .restricted: AppLocalization.string("无法访问日历")
        case .failed: AppLocalization.string("日历同步失败")
        }
    }

    var message: String {
        switch self {
        case .permissionDenied:
            AppLocalization.string("要同步训练计划，请在系统设置中允许 RepDay 完全访问日历。")
        case .restricted:
            AppLocalization.string("这台设备限制了日历访问，可能需要检查家长控制或设备管理设置。")
        case .failed:
            AppLocalization.string("训练计划暂时无法写入日历，请稍后重试。")
        }
    }
}

// A Tiimo-style pill segmented control used to switch between modes.
private struct PlanModeToggle: View {
    @Binding var mode: PlanMode
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PlanMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { mode = m }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .appScaledFont(size: 12, relativeTo: .caption, weight: .semibold)
                        Text(
                            AppLocalization.string(
                                m.rawValue,
                                languageIdentifier: locale.identifier
                            )
                        )
                            .appScaledFont(size: 14, relativeTo: .subheadline, weight: .semibold)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query private var workoutDays: [WorkoutDay]

    @State private var isSyncing = false
    @State private var showSuccessFeedback = false
    @State private var calendarSyncIssue: CalendarSyncIssue?
    @State private var waitingForCalendarSettings = false
    @State private var planMode: PlanMode = .plan
    @State private var shimmerX: CGFloat = -0.6

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Theme.Spacing.m),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

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
                totalSets: day.exercises.filter { !$0.isCardio }.reduce(0) { $0 + $1.sets },
                cardioMinutes: day.exercises.filter(\.isCardio).reduce(0) { $0 + $1.targetDurationSeconds } / 60,
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
            .alert(item: $calendarSyncIssue) { issue in
                if issue == .permissionDenied {
                    return Alert(
                        title: Text(issue.title),
                        message: Text(issue.message),
                        primaryButton: .cancel(Text("取消")),
                        secondaryButton: .default(Text("前往系统设置")) {
                            openCalendarSettings()
                        }
                    )
                }
                return Alert(
                    title: Text(issue.title),
                    message: Text(issue.message),
                    dismissButton: .default(Text("好"))
                )
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, waitingForCalendarSettings else { return }
                waitingForCalendarSettings = false
                if CalendarManager.shared.authorizationState == .allowed {
                    syncToCalendar()
                }
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

            templateLibraryLink
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

    private var templateLibraryLink: some View {
        NavigationLink(destination: TemplateLibraryView()) {
            HStack(spacing: Theme.Spacing.m) {
                EmojiTile(emoji: "🗂️", tint: Theme.Color.tintBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("模板库")
                        .appScaledFont(size: 16, relativeTo: .body, weight: .semibold)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("建好模板，一键套用到任意一天")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .tiimoCard()
        }
        .buttonStyle(.plain)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("健身课表")
                .font(.displayLarge)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(
                AppLocalization.string(
                    planMode == .plan ? "管理每周训练计划" : "随心所欲，今天练啥？"
                )
            )
                .appScaledFont(size: 15, relativeTo: .subheadline, weight: .medium)
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
                    Text("同步中...")
                } else if showSuccessFeedback {
                    Image(systemName: "checkmark.circle.fill")
                    Text("同步成功！")
                } else {
                    Image(systemName: "calendar.badge.plus")
                    Text("同步到日历")
                }
            }
            .appScaledFont(size: 17, relativeTo: .headline, weight: .bold)
            .foregroundStyle(showSuccessFeedback ? .white : Theme.Color.ctaLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if showSuccessFeedback {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: 0xB91C1C), Color(hex: 0xDC2626), Color(hex: 0xF97066)],
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
            .shadow(color: Color(hex: 0xDC2626).opacity(showSuccessFeedback ? 0.4 : 0), radius: 16, y: 8)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    private var isToday: Bool {
        workoutDay.dayName == WeekPlanSummary.todayDayName()
    }

    private var totalSets: Int {
        workoutDay.exercises.filter { !$0.isCardio }.reduce(0) { $0 + $1.sets }
    }

    private var cardioMinutes: Int {
        workoutDay.exercises.filter(\.isCardio).reduce(0) { $0 + $1.targetDurationSeconds } / 60
    }

    private var intensityEmoji: String {
        if workoutDay.isRestDay { return "🛋️" }
        if workoutDay.exercises.isEmpty { return "📋" }
        if totalSets < 12 { return "💧" }
        if totalSets <= 20 { return "🔥" }
        return "💀"
    }

    private var intensityLabel: String {
        let key: String
        if totalSets < 12 {
            key = "适中"
        } else if totalSets <= 20 {
            key = "高燃"
        } else {
            key = "极限"
        }
        return AppLocalization.string(
            key,
            languageIdentifier: locale.identifier
        )
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
                    .appScaledFont(size: 15, relativeTo: .subheadline, weight: .bold)
                    .foregroundStyle(isToday ? Theme.Color.accent : Theme.Color.textPrimary)
                Spacer()
                if workoutDay.isRestDay {
                    Text("休息")
                        .appScaledFont(size: 11, relativeTo: .caption2, weight: .bold)
                        .foregroundStyle(Theme.Color.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Color.tintMint, in: Capsule())
                } else if isToday {
                    Text("今天")
                        .appScaledFont(size: 11, relativeTo: .caption2, weight: .bold)
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
                            Text("• \(ExerciseLibrary.displayName(for: exercise.name))")
                                .appScaledFont(size: 12, relativeTo: .caption, weight: .medium)
                                .foregroundStyle(Theme.Color.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(
                                exercise.isCardio
                                    ? ExerciseFormatting.shortDuration(exercise.targetDurationSeconds)
                                    : AppLocalization.format(
                                        "%lld组",
                                        languageIdentifier: locale.identifier,
                                        exercise.sets
                                    )
                            )
                                .appScaledFont(size: 11, relativeTo: .caption2)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                    if workoutDay.exercises.count > 2 {
                        Text("等共 \(workoutDay.exercises.count) 个动作")
                            .appScaledFont(size: 10, relativeTo: .caption2)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                HStack {
                    Text("\(intensityEmoji) \(intensityLabel)")
                        .appScaledFont(size: 10, relativeTo: .caption2, weight: .bold)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(intensityColor, in: Capsule())
                    Spacer()
                    Text(
                        cardioMinutes > 0
                            ? AppLocalization.format(
                                "%lld 组 · %lld 分",
                                languageIdentifier: locale.identifier,
                                totalSets,
                                cardioMinutes
                            )
                            : AppLocalization.format(
                                "%lld 组",
                                languageIdentifier: locale.identifier,
                                totalSets
                            )
                    )
                        .appScaledFont(size: 11, relativeTo: .caption2, weight: .semibold)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(height: usesAppStoreCardHeight ? 165 : nil)
        .frame(minHeight: 165)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(isToday ? Theme.Color.accent : Theme.Color.hairline,
                        lineWidth: isToday ? 1.5 : 1)
        )
        .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
    }

    private var usesAppStoreCardHeight: Bool {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large:
            true
        default:
            false
        }
    }
}

// MARK: - Day detail editor (fully custom Tiimo-style layout)

struct DayDetailEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.locale) private var locale
    @Bindable var workoutDay: WorkoutDay
    @Query private var templates: [WorkoutTemplate]

    @State private var newExerciseName = ""
    @State private var newSets = 4
    @State private var newReps = 12
    @State private var newActivityType: ExerciseActivityType = .strength
    @State private var newDurationSeconds = 20 * 60
    @State private var showingExercisePicker = false
    @FocusState private var nameFieldFocused: Bool

    private var sortedExercises: [Exercise] {
        workoutDay.exercises.sorted(by: { $0.order < $1.order })
    }

    var totalSets: Int { workoutDay.exercises.filter { !$0.isCardio }.reduce(0) { $0 + $1.sets } }
    var totalReps: Int { workoutDay.exercises.filter { !$0.isCardio }.reduce(0) { $0 + $1.sets * $1.reps } }
    var cardioMinutes: Int {
        workoutDay.exercises.filter(\.isCardio).reduce(0) { $0 + $1.targetDurationSeconds } / 60
    }

    /// Rough session estimate: each set ≈ working time (reps×3s) + one rest.
    private var estimatedMinutes: Int {
        let seconds = workoutDay.exercises.reduce(0) { acc, ex in
            if ex.isCardio {
                return acc + ex.targetDurationSeconds
            }
            let restSeconds = ex.restSeconds ?? AppSettings.shared.defaultRestSeconds
            return acc + ex.sets * (ex.reps * 3 + restSeconds)
        }
        return max(1, Int((Double(seconds) / 60).rounded()))
    }

    var availableTemplates: [WorkoutTemplate] {
        templates
            .filter { !$0.exercises.isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    dayTypePicker

                    if workoutDay.isRestDay {
                        restDayStatusCard
                            .transition(.opacity)
                    } else {
                        if !workoutDay.exercises.isEmpty {
                            summaryCard
                        }
                        exercisesSection(scrollProxy: proxy)
                        composerSection
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xxl)
                .animation(
                    accessibilityReduceMotion ? nil : .easeInOut(duration: 0.22),
                    value: workoutDay.isRestDay
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: workoutDay.exercises.count)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(
                AppLocalization.format(
                    "%@ 安排",
                    WeekdayDisplay.fullLabel(for: workoutDay.dayName)
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerSheet(
                    selectedNames: Set(workoutDay.exercises.map(\.name)),
                    onSelect: addExerciseFromLibrary
                )
            }
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
            .onChange(of: nameFieldFocused) { _, isFocused in
                guard isFocused else { return }
                revealInput("dayComposerNameField", using: proxy)
            }
        }
        .appKeyboardToolbar()
    }

    private func revealInput(_ id: String, using proxy: ScrollViewProxy) {
        withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.25)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    // MARK: Day type

    private var dayTypePicker: some View {
        Picker("当天类型", selection: $workoutDay.isRestDay) {
            Text("训练日").tag(false)
            Text("休息日").tag(true)
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .onChange(of: workoutDay.isRestDay) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private var restDayStatusCard: some View {
        HStack(spacing: Theme.Spacing.m) {
            EmojiTile(emoji: "🔋", tint: Theme.Color.tintMint)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    AppLocalization.string(
                        "今天不安排训练",
                        languageIdentifier: locale.identifier
                    )
                )
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(
                    AppLocalization.string(
                        workoutDay.exercises.isEmpty
                            ? "肌肉正在修复，好好放松"
                            : "已编排的动作会保留，切回训练日后继续编辑",
                        languageIdentifier: locale.identifier
                    )
                )
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
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
            if cardioMinutes > 0 {
                summaryStat(value: "\(cardioMinutes)", label: "有氧", unit: "分")
            } else {
                summaryStat(value: "~\(estimatedMinutes)", label: "预计时长", unit: "分")
            }
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
                    .font(.displayMetricSmall)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(AppLocalization.string(unit))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Text(AppLocalization.string(label))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Exercises

    private func exercisesSection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "已编排动作", count: workoutDay.exercises.count,
                        systemImage: "dumbbell.fill", tint: Theme.Color.tintPeach)

            if workoutDay.exercises.isEmpty {
                emptyExercisesCard
            } else {
                ForEach(Array(sortedExercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                    let nameFieldID = "dayExerciseName-\(exercise.persistentModelID)"
                    ExerciseEditorCard(
                        exercise: exercise,
                        canMoveUp: index > 0,
                        canMoveDown: index < sortedExercises.count - 1,
                        onMoveUp: { moveExercise(at: index, by: -1) },
                        onMoveDown: { moveExercise(at: index, by: 1) },
                        onDelete: { deleteExercise(exercise) },
                        onNameFocus: { revealInput(nameFieldID, using: scrollProxy) }
                    )
                    .id(nameFieldID)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
        }
    }

    private var emptyExercisesCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("🗒️").font(.system(size: 36))
            Text("还没有安排动作")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)

            if !availableTemplates.isEmpty {
                Menu {
                    ForEach(availableTemplates) { template in
                        Button("套用「\(template.name)」(\(template.exercises.count) 个动作)") {
                            copyExercises(from: template)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("从模板库套用课表")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(Theme.Color.accentSoft, in: Capsule())
                }

                Text("或在下方手动添加动作")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            } else {
                NavigationLink(destination: TemplateLibraryView()) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.square.on.square")
                        Text("去模板库创建模板")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(Theme.Color.accentSoft, in: Capsule())
                }

                Text("或在下方手动添加你的第一个动作")
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
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("浏览动作库", systemImage: "books.vertical.fill")
                }
                .buttonStyle(.primaryCTA)

                HStack {
                    Divider()
                    Text("或添加自定义动作")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Divider()
                }

                TextField("", text: $newExerciseName, prompt: Text("输入动作名称").foregroundColor(Theme.Color.textSecondary))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .focused($nameFieldFocused)
                    .id("dayComposerNameField")
                    .submitLabel(.done)
                    .onSubmit(addExercise)
                    .themedField(isFocused: nameFieldFocused)

                Picker("训练类型", selection: $newActivityType) {
                    ForEach(ExerciseActivityType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if newActivityType == .cardio {
                    DurationSettingControl(title: "目标时长", seconds: $newDurationSeconds)
                } else {
                    HStack(spacing: Theme.Spacing.xl) {
                        ThemedStepper(title: "训练组数", value: $newSets, range: 1...10)
                        ThemedStepper(title: "每组次数", value: $newReps, range: 1...99)
                        Spacer()
                    }
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
            workoutDay.exercises.append(
                Exercise(
                    name: trimmed,
                    sets: newActivityType == .cardio ? 0 : newSets,
                    reps: newActivityType == .cardio ? 0 : newReps,
                    order: workoutDay.exercises.count,
                    activityType: newActivityType,
                    trackingMode: newActivityType == .cardio ? .duration : .setsAndReps,
                    targetDurationSeconds: newActivityType == .cardio ? newDurationSeconds : 0
                )
            )
        }
        newExerciseName = ""
        nameFieldFocused = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func addExerciseFromLibrary(_ definition: ExerciseDefinition) {
        guard !workoutDay.exercises.contains(where: { $0.name == definition.name }) else { return }
        withAnimation {
            workoutDay.exercises.append(
                Exercise(
                    name: definition.name,
                    sets: definition.trackingMode == .duration ? 0 : definition.defaultSets,
                    reps: definition.trackingMode == .duration ? 0 : definition.defaultReps,
                    order: workoutDay.exercises.count,
                    activityType: definition.activityType,
                    trackingMode: definition.trackingMode,
                    targetDurationSeconds: definition.trackingMode == .duration ? definition.defaultDurationSeconds : 0
                )
            )
        }
        try? modelContext.save()
    }

    private func deleteExercise(_ exercise: Exercise) {
        RestTimerCoordinator.shared.cancel(
            timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
        )
        CardioGoalCoordinator.shared.cancel(
            timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
        )
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

    private func copyExercises(from template: WorkoutTemplate) {
        let sorted = template.exercises.sorted(by: { $0.order < $1.order })
        let base = workoutDay.exercises.count
        withAnimation {
            for (index, ex) in sorted.enumerated() {
                workoutDay.exercises.append(
                    Exercise(
                        name: ex.name,
                        sets: ex.sets,
                        reps: ex.reps,
                        order: base + index,
                        activityType: ex.activityType,
                        trackingMode: ex.trackingMode,
                        targetDurationSeconds: ex.targetDurationSeconds
                    )
                )
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
    let onNameFocus: () -> Void

    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                ExerciseIconTile(name: exercise.name, activityType: exercise.activityType)

                TextField("动作名称", text: $exercise.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFieldFocused = false }
                    .onChange(of: nameFieldFocused) { _, isFocused in
                        if isFocused {
                            onNameFocus()
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(
                        nameFieldFocused ? Theme.Color.accentSoft : Color.clear,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            .stroke(
                                nameFieldFocused ? Theme.Color.accent : Color.clear,
                                lineWidth: 1.5
                            )
                    )

                Menu {
                    if canMoveUp { Button { onMoveUp() } label: { Label("上移", systemImage: "arrow.up") } }
                    if canMoveDown { Button { onMoveDown() } label: { Label("下移", systemImage: "arrow.down") } }
                    Button(role: .destructive, action: onDelete) { Label("删除动作", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .appScaledFont(size: 16, relativeTo: .body, weight: .semibold)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Color.surfaceMuted, in: Circle())
                        .contentShape(Rectangle().inset(by: -6))
                }
            }

            Divider().background(Theme.Color.hairline)

            if exercise.isCardio {
                DurationSettingControl(title: "目标时长", seconds: $exercise.targetDurationSeconds)
            } else {
                HStack(spacing: Theme.Spacing.xl) {
                    ThemedStepper(title: "组数", value: $exercise.sets, range: 1...20)
                    ThemedStepper(title: "次数", value: $exercise.reps, range: 1...100)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("总计")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                        Text("\(exercise.sets * exercise.reps) 次")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.Color.accent)
                    }
                }
            }

            if !exercise.isCardio {
                Menu {
                    Button("使用全局默认（\(formattedRest(AppSettings.shared.defaultRestSeconds))）") {
                        exercise.restSeconds = nil
                    }
                    Divider()
                    ForEach([30, 60, 90, 120, 180], id: \.self) { seconds in
                        Button(formattedRest(seconds)) {
                            exercise.restSeconds = seconds
                        }
                    }
                } label: {
                    HStack {
                        Label("动作休息时长", systemImage: "timer")
                        Spacer()
                        Text(formattedRest(exercise.restSeconds ?? AppSettings.shared.defaultRestSeconds))
                            .monospacedDigit()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(minHeight: 44)
                }
            }
        }
        .tiimoCard()
    }

    private func formattedRest(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - PlanSetupView logic extension

extension PlanSetupView {
    private func syncToCalendar() {
        isSyncing = true
        Task {
            let result = await CalendarManager.shared.requestAccessAndSync(workoutDays: sortedDays)
            await MainActor.run {
                isSyncing = false
                switch result {
                case .success:
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showSuccessFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.3)) { showSuccessFeedback = false }
                    }
                case .permissionDenied:
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    calendarSyncIssue = .permissionDenied
                case .restricted:
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    calendarSyncIssue = .restricted
                case .failed:
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    calendarSyncIssue = .failed
                }
            }
        }
    }

    private func openCalendarSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        waitingForCalendarSettings = true
        openURL(url)
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
