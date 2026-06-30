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
    @Query private var workoutDays: [WorkoutDay]
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse) private var sessions: [WorkoutSession]

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

    private var todayCompletedSets: Int {
        guard let plan = todayPlan else { return 0 }
        return WorkoutHistoryManager.completedSetCount(for: plan)
    }

    private var todayPlannedSets: Int {
        guard let plan = todayPlan else { return 0 }
        return WorkoutHistoryManager.plannedSetCount(for: plan)
    }

    private var weeklyChartEntries: [WeeklyChartEntry] {
        weeklyStats.flatMap { stat in [
            WeeklyChartEntry(id: "\(stat.dayName)-plan", dayName: stat.dayName, kind: "计划", value: stat.plannedSets),
            WeeklyChartEntry(id: "\(stat.dayName)-actual", dayName: stat.dayName, kind: "实际", value: stat.completedSets)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: Overview pills

    private var overviewPills: some View {
        HStack(spacing: Theme.Spacing.m) {
            statPill(value: "\(streak)", label: "连续打卡", unit: "天", tint: Theme.Color.tintPeach)
            statPill(value: "\(sessions.count)", label: "历史训练", unit: "次", tint: Theme.Color.tintBlue)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func statPill(value: String, label: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.display(32, weight: .bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(unit)
                    .font(.system(size: 15, weight: .medium))
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

            if let plan = todayPlan, !plan.isRestDay, !plan.exercises.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(todayCompletedSets)")
                                .font(.display(36, weight: .bold))
                                .foregroundStyle(Theme.Color.textPrimary)
                            Text("/ \(todayPlannedSets) 组")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        Text(plan.dayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Spacer()
                    RingProgressView(
                        progress: todayPlannedSets > 0
                            ? Double(todayCompletedSets) / Double(todayPlannedSets)
                            : 0,
                        size: 64
                    )
                }
            } else {
                Text("今日休息或无训练安排")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Color.textSecondary)
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
                "计划": Theme.Color.accentSoft,
                "实际": Theme.Color.accent
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
                Text(session.dayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(session.sessionDate, format: .dateTime.month().day().weekday(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(session.completedSetCount)/\(session.plannedSetCount) 组")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                Text(session.isComplete ? "已完成" : "部分完成")
                    .font(.caption)
                    .foregroundStyle(session.isComplete ? Theme.Color.success : Color.orange)
            }
        }
        .padding(.vertical, Theme.Spacing.m)
    }

    // MARK: Quote

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("\"")
                .font(.display(40, weight: .bold))
                .foregroundStyle(Theme.Color.accent)
                .offset(y: 8)

            Text("自律不是一种行为，而是一种习惯。你挥洒的每一滴汗水，日历和身体都会帮你记住。")
                .font(.system(size: 15, weight: .regular))
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
        .modelContainer(for: [WorkoutDay.self, WorkoutSession.self, SetLog.self], inMemory: true)
}
