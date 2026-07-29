//
//  AnalyticsView.swift
//  FitnessApp
//
//  Restyled with the Tiimo-inspired Theme system. All Charts, SwiftData queries,
//  and WorkoutHistoryManager logic are untouched — only the presentation layer changed.
//

import SwiftUI
import Charts
import SwiftData

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var workoutDays: [WorkoutDay]
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<Exercise> { $0.isImprov }) private var improvExercises: [Exercise]
    /// Set by TodayWorkoutView when an improv workout is finished — while it
    /// matches today, today's numbers come from the stored session record
    /// rather than the (untouched, 0-progress) weekly plan.
    @AppStorage("improvFinishedDayStamp") private var improvFinishedDayStamp: Double = 0

    private struct WeeklyChartEntry: Identifiable {
        let id: String
        let dayName: String
        let kind: String
        let value: Int
    }

    private var streak: Int {
        WorkoutHistoryManager.currentStreak(context: modelContext)
    }

    private var weeklyStats: [(dayName: String, plannedSets: Int, completedSets: Int)] {
        WorkoutHistoryManager.weeklyDayStats(context: modelContext, workoutDays: workoutDays)
    }

    private var todayPlan: WorkoutDay? {
        let dayName = WorkoutHistoryManager.todayWeekdayString()
        return workoutDays.first { $0.dayName == dayName }
    }

    private var todayImprovExercises: [Exercise] {
        improvExercises.filter { $0.sessionDate.map { Calendar.current.isDateInToday($0) } ?? false }
    }

    private var isImprovActiveToday: Bool { !todayImprovExercises.isEmpty }

    private var isDayFinishedToday: Bool {
        improvFinishedDayStamp == WorkoutHistoryManager.startOfDay().timeIntervalSince1970
    }

    /// Today's frozen session record (only consulted once improv is finished —
    /// the live @Query keeps this current without a manual fetch).
    private var todayFinishedSession: WorkoutSession? {
        sessions.first { Calendar.current.isDate($0.sessionDate, inSameDayAs: .now) }
    }

    private var todayCompletedSets: Int {
        if isImprovActiveToday {
            return WorkoutHistoryManager.completedSetCount(for: todayImprovExercises)
        }
        if isDayFinishedToday {
            return todayFinishedSession?.completedSetCount ?? 0
        }
        guard let plan = todayPlan else { return 0 }
        return WorkoutHistoryManager.completedSetCount(for: plan)
    }

    private var todayPlannedSets: Int {
        if isImprovActiveToday {
            return WorkoutHistoryManager.plannedSetCount(for: todayImprovExercises)
        }
        if isDayFinishedToday {
            return todayFinishedSession?.plannedSetCount ?? 0
        }
        guard let plan = todayPlan else { return 0 }
        return WorkoutHistoryManager.plannedSetCount(for: plan)
    }

    private var todayCompletedCardio: Int {
        if isImprovActiveToday {
            return WorkoutHistoryManager.completedCardioCount(for: todayImprovExercises)
        }
        if isDayFinishedToday {
            return todayFinishedSession?.completedCardioCount ?? 0
        }
        return todayPlan.map { WorkoutHistoryManager.completedCardioCount(for: $0.exercises) } ?? 0
    }

    private var todayPlannedCardio: Int {
        if isImprovActiveToday {
            return WorkoutHistoryManager.plannedCardioCount(for: todayImprovExercises)
        }
        if isDayFinishedToday {
            return todayFinishedSession?.plannedCardioCount ?? 0
        }
        return todayPlan.map { WorkoutHistoryManager.plannedCardioCount(for: $0.exercises) } ?? 0
    }

    private var todayCardioDurationSeconds: Int {
        if isImprovActiveToday {
            return WorkoutHistoryManager.completedCardioDuration(for: todayImprovExercises)
        }
        if isDayFinishedToday {
            return todayFinishedSession?.completedCardioDurationSeconds ?? 0
        }
        return todayPlan.map { WorkoutHistoryManager.completedCardioDuration(for: $0.exercises) } ?? 0
    }

    private var weeklyChartEntries: [WeeklyChartEntry] {
        weeklyStats.flatMap { stat in [
            WeeklyChartEntry(
                id: "\(stat.dayName)-plan",
                dayName: WeekdayDisplay.label(for: stat.dayName),
                kind: AppLocalization.string("计划"),
                value: stat.plannedSets
            ),
            WeeklyChartEntry(
                id: "\(stat.dayName)-actual",
                dayName: WeekdayDisplay.label(for: stat.dayName),
                kind: AppLocalization.string("实际"),
                value: stat.completedSets
            )
        ]}
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    pageHeader
                    overviewPills
                    todayLiveCard
                    weeklyChart
                    volumeTrendCard
                    cardioTrendCard
                    historyCard
                    quoteCard
                }
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

extension AnalyticsView {

    // MARK: Page header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("数据统计")
                .font(.displayLarge)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(Date.now, format: .dateTime.month(.wide).day().year())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: Overview pills

    private var overviewPills: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Theme.Spacing.m) {
                    statPill(value: "\(streak)", label: "连续打卡", unit: "天", tint: Theme.Color.tintPeach)
                    statPill(value: "\(sessions.count)", label: "历史训练", unit: "次", tint: Theme.Color.tintBlue)
                }
            } else {
                HStack(spacing: Theme.Spacing.m) {
                    statPill(value: "\(streak)", label: "连续打卡", unit: "天", tint: Theme.Color.tintPeach)
                    statPill(value: "\(sessions.count)", label: "历史训练", unit: "次", tint: Theme.Color.tintBlue)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func statPill(value: String, label: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(AppLocalization.string(label))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.displayMetric)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(AppLocalization.string(unit))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: Today live card

    private var todayLiveCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "今日实时进度", systemImage: "bolt.fill", tint: Theme.Color.tintPeach)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isImprovActiveToday || isDayFinishedToday || (todayPlan.map { !$0.isRestDay && !$0.exercises.isEmpty } ?? false) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        todayProgressText
                        todayProgressRing
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack {
                        todayProgressText
                        Spacer()
                        todayProgressRing
                    }
                }
            } else {
                Text("今日休息或无训练安排")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .tiimoCard()
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var todayProgressText: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                if todayPlannedSets > 0 {
                    Text("\(todayCompletedSets)")
                        .font(.displayMetricLarge)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("/ \(todayPlannedSets) 组")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                } else {
                    Text("\(todayCardioDurationSeconds / 60)")
                        .font(.displayMetricLarge)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("分钟有氧")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            if todayPlannedCardio > 0 {
                Text("\(todayCompletedCardio) / \(todayPlannedCardio) 项有氧 · \(todayCardioDurationSeconds / 60) 分钟")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Text(todayWorkoutLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var todayProgressRing: some View {
        let plannedUnits = todayPlannedSets + todayPlannedCardio
        let completedUnits = todayCompletedSets + todayCompletedCardio
        return RingProgressView(
            progress: plannedUnits > 0
                ? Double(completedUnits) / Double(plannedUnits)
                : 0,
            size: 64
        )
    }

    private var cardioTrendCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionPill(title: "近期有氧时长", systemImage: "figure.run", tint: Theme.Color.tintMint)
                .frame(maxWidth: .infinity, alignment: .leading)

            let recent = Array(sessions.prefix(7).reversed())
            let hasCardio = recent.contains { $0.completedCardioDurationSeconds > 0 }

            if hasCardio {
                Chart(recent, id: \.persistentModelID) { session in
                    BarMark(
                        x: .value("日期", session.sessionDate, unit: .day),
                        y: .value("分钟", Double(session.completedCardioDurationSeconds) / 60)
                    )
                    .foregroundStyle(Theme.Color.success)
                    .cornerRadius(5)
                }
                .frame(height: 160)
                .chartYAxis { AxisMarks(position: .leading) }
            } else {
                Text("完成第一次有氧训练后，这里会显示分钟趋势")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            }
        }
        .tiimoCard()
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: Weekly chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionPill(title: "本周计划 vs 实际", systemImage: "chart.bar.fill", tint: Theme.Color.tintBlue)
                .frame(maxWidth: .infinity, alignment: .leading)

            Chart(weeklyChartEntries) { entry in
                BarMark(
                    x: .value("星期", entry.dayName),
                    y: .value("组数", entry.value)
                )
                .foregroundStyle(by: .value("类型", entry.kind))
                .cornerRadius(6)
            }
            .chartForegroundStyleScale([
                AppLocalization.string("计划"): Theme.Color.accentSoft,
                AppLocalization.string("实际"): Theme.Color.accent
            ])
            .frame(height: 220)
            .chartYAxis { AxisMarks(position: .leading) }
        }
        .tiimoCard()
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: Volume trend

    private var volumeTrendCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionPill(title: "近期完成趋势", systemImage: "chart.line.uptrend.xyaxis", tint: Theme.Color.tintMint)
                .frame(maxWidth: .infinity, alignment: .leading)

            let recent = Array(sessions.prefix(7).reversed())

            if recent.isEmpty {
                Text("完成第一次训练后，这里会显示趋势图")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                Chart(recent, id: \.persistentModelID) { session in
                    LineMark(
                        x: .value("日期", session.sessionDate, unit: .day),
                        y: .value("组数", session.completedSetCount)
                    )
                    .foregroundStyle(Theme.Color.accent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("日期", session.sessionDate, unit: .day),
                        y: .value("组数", session.completedSetCount)
                    )
                    .foregroundStyle(Theme.Color.accent.opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", session.sessionDate, unit: .day),
                        y: .value("组数", session.completedSetCount)
                    )
                    .foregroundStyle(Theme.Color.accent)
                    .symbolSize(40)
                }
                .frame(height: 180)
                .chartYAxis { AxisMarks(position: .leading) }
            }
        }
        .tiimoCard()
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionPill(title: "训练历史", systemImage: "clock.fill", tint: Theme.Color.surfaceMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if sessions.isEmpty {
                Text("暂无历史记录，完成今日训练后将自动保存")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Color.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.prefix(10).enumerated()), id: \.element.persistentModelID) { index, session in
                        historyRow(session)
                        if index < min(sessions.count, 10) - 1 {
                            Divider()
                                .background(Theme.Color.hairline)
                                .padding(.horizontal, Theme.Spacing.s)
                        }
                    }
                }
            }
        }
        .tiimoCard()
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func historyRow(_ session: WorkoutSession) -> some View {
        HStack {
            EmojiTile(emoji: "🏋️", tint: Theme.Color.accentSoft, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.string(session.dayName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(session.sessionDate, format: .dateTime.month().day().weekday(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(historySummary(session))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
                Text(session.isComplete ? "已完成" : "部分完成")
                    .font(.caption)
                    .foregroundStyle(session.isComplete ? Theme.Color.success : Color.orange)
            }
        }
        .padding(.vertical, Theme.Spacing.m)
    }

    private func historySummary(_ session: WorkoutSession) -> String {
        var parts: [String] = []
        if session.plannedSetCount > 0 {
            parts.append(
                AppLocalization.format(
                    "%lld / %lld 组",
                    session.completedSetCount,
                    session.plannedSetCount
                )
            )
        }
        if session.plannedCardioCount > 0 {
            parts.append(
                AppLocalization.format(
                    "%lld 分有氧",
                    session.completedCardioDurationSeconds / 60
                )
            )
        }
        return parts.isEmpty
            ? AppLocalization.string("暂无记录")
            : parts.joined(separator: " · ")
    }

    private var todayWorkoutLabel: String {
        if isImprovActiveToday {
            return AppLocalization.string("即兴训练")
        }
        if isDayFinishedToday {
            return [
                AppLocalization.string("即兴训练"),
                AppLocalization.string("已完成")
            ].joined(separator: " · ")
        }
        return todayPlan.map { WeekdayDisplay.fullLabel(for: $0.dayName) } ?? ""
    }

    // MARK: Quote

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("\"")
                .font(.displayMetricLarge)
                .foregroundStyle(Theme.Color.accent)
                .offset(y: 8)

            Text("自律不是一种行为，而是一种习惯。你挥洒的每一滴汗水，日历和身体都会帮你记住。")
                .font(.subheadline)
                .italic()
                .foregroundStyle(Theme.Color.textSecondary)
                .lineSpacing(5)
        }
        .tiimoCard(padding: Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [WorkoutDay.self, WorkoutSession.self, SetLog.self, CardioLog.self], inMemory: true)
}
