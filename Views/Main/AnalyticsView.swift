//
//  AnalyticsView.swift
//  FitnessApp
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
        weeklyStats.flatMap { stat in
            [
                WeeklyChartEntry(id: "\(stat.dayName)-plan", dayName: stat.dayName, kind: "计划", value: stat.plannedSets),
                WeeklyChartEntry(id: "\(stat.dayName)-actual", dayName: stat.dayName, kind: "实际", value: stat.completedSets)
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    overviewHeader
                    todayLiveCard
                    weeklyCompletionChart
                    volumeTrendChart
                    historySection
                    motivationalBox
                }
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("数据统计")
        }
    }
}

extension AnalyticsView {
    
    private var overviewHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("连续打卡")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(streak) 天")
                    .font(.title2.bold())
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("历史训练")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(sessions.count) 次")
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
    
    private var todayLiveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日实时进度")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let plan = todayPlan, !plan.isRestDay, !plan.exercises.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(todayCompletedSets) / \(todayPlannedSets) 组")
                            .font(.title.bold())
                            .foregroundColor(.accentColor)
                        Text(plan.dayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    RingProgressView(
                        progress: todayPlannedSets > 0
                            ? Double(todayCompletedSets) / Double(todayPlannedSets)
                            : 0,
                        size: 56
                    )
                }
            } else {
                Text("今日休息或无训练安排")
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
    
    private var weeklyCompletionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本周计划 vs 实际完成（组数）")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Chart(weeklyChartEntries) { entry in
                BarMark(
                    x: .value("星期", entry.dayName),
                    y: .value("组数", entry.value)
                )
                .foregroundStyle(by: .value("类型", entry.kind))
                .cornerRadius(4)
            }
            .chartForegroundStyleScale([
                "计划": Color.secondary.opacity(0.35),
                "实际": Color.accentColor
            ])
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
    
    private var volumeTrendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("近期完成组数趋势")
                .font(.headline)
                .foregroundColor(.secondary)
            
            let recent = Array(sessions.prefix(7).reversed())
            
            if recent.isEmpty {
                Text("完成第一次训练后，这里会显示趋势图")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart(recent, id: \.persistentModelID) { session in
                    LineMark(
                        x: .value("日期", session.sessionDate, unit: .day),
                        y: .value("组数", session.completedSetCount)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("日期", session.sessionDate, unit: .day),
                        y: .value("组数", session.completedSetCount)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练历史")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if sessions.isEmpty {
                Text("暂无历史记录，完成今日训练后将自动保存")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(sessions.prefix(10)) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.dayName)
                                .font(.subheadline.bold())
                            Text(session.sessionDate, format: .dateTime.month().day().weekday(.abbreviated))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(session.completedSetCount)/\(session.plannedSetCount) 组")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.accentColor)
                            Text(session.isComplete ? "已完成" : "部分完成")
                                .font(.caption)
                                .foregroundColor(session.isComplete ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    if session.persistentModelID != sessions.prefix(10).last?.persistentModelID {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
    
    private var motivationalBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            
            Text("自律不是一种行为，而是一种习惯。你挥洒的每一滴汗水，日历和身体都会帮你记住。")
                .font(.subheadline)
                .italic()
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [WorkoutDay.self, WorkoutSession.self, SetLog.self], inMemory: true)
}
