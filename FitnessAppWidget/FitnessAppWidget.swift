import WidgetKit
import SwiftUI

struct FitnessAppWidgetEntry: TimelineEntry {
    let date: Date
    let completedSets: Int
    let totalSets: Int
    let completedExercises: Int
    let totalExercises: Int
    let dayName: String
    let isRestDay: Bool
    let isWorkoutComplete: Bool
    let exercisePreview: String
    let streak: Int
    let nextWorkoutDayName: String?
    let nextWorkoutPreview: String?
    let weekOverview: WeekPlanSummary.Overview?
    
    var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }
    
    static func fromStore(date: Date = .now) -> FitnessAppWidgetEntry {
        FitnessAppWidgetEntry(
            date: date,
            completedSets: WidgetDataStore.completedSets,
            totalSets: WidgetDataStore.totalSets,
            completedExercises: WidgetDataStore.completedExercises,
            totalExercises: WidgetDataStore.totalExercises,
            dayName: WidgetDataStore.dayName,
            isRestDay: WidgetDataStore.isRestDay,
            isWorkoutComplete: WidgetDataStore.isWorkoutComplete,
            exercisePreview: WidgetDataStore.exercisePreview,
            streak: WidgetDataStore.streak,
            nextWorkoutDayName: WidgetDataStore.nextWorkoutDayName,
            nextWorkoutPreview: WidgetDataStore.nextWorkoutPreview,
            weekOverview: WidgetDataStore.weekOverview
        )
    }
}

struct FitnessAppWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FitnessAppWidgetEntry {
        FitnessAppWidgetEntry(
            date: .now,
            completedSets: 6,
            totalSets: 20,
            completedExercises: 1,
            totalExercises: 4,
            dayName: "周三",
            isRestDay: false,
            isWorkoutComplete: false,
            exercisePreview: "硬拉 · 划船",
            streak: 12,
            nextWorkoutDayName: "周四",
            nextWorkoutPreview: "推举 · 侧平举",
            weekOverview: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FitnessAppWidgetEntry) -> Void) {
        completion(FitnessAppWidgetEntry.fromStore())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FitnessAppWidgetEntry>) -> Void) {
        let entry = FitnessAppWidgetEntry.fromStore()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct FitnessAppWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FitnessAppWidgetEntry
    
    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        default:
            smallView
        }
    }
    
    private var smallView: some View {
        Group {
            if entry.isRestDay {
                restDaySmallView
            } else if entry.isWorkoutComplete {
                completeSmallView
            } else {
                trainingSmallView
            }
        }
        .padding()
    }
    
    private var restDaySmallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("今日休息", systemImage: "battery.100")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            
            Spacer(minLength: 0)
            
            if let nextDay = entry.nextWorkoutDayName {
                Text("下次：\(nextDay)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let preview = entry.nextWorkoutPreview, !preview.isEmpty {
                    Text(preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var completeSmallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("今日已完成", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            
            Text("\(entry.completedSets)/\(entry.totalSets) 组")
                .font(.title2.bold())
            
            if entry.streak > 0 {
                Text("连续 \(entry.streak) 天")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var trainingSmallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.dayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(entry.progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }
            
            Text("\(entry.completedSets)/\(entry.totalSets) 组")
                .font(.title2.bold())
            
            ProgressView(value: entry.progress)
                .tint(Color.accentColor)
            
            if !entry.exercisePreview.isEmpty {
                Text(entry.exercisePreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("\(entry.completedExercises)/\(entry.totalExercises) 个动作")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if entry.isRestDay {
                        Label("今日休息", systemImage: "battery.100")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else if entry.isWorkoutComplete {
                        Label("今日已完成", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(entry.dayName) · 训练中")
                            .font(.subheadline.weight(.semibold))
                    }
                    
                    if entry.isRestDay {
                        if let nextDay = entry.nextWorkoutDayName {
                            Text("下次 \(nextDay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("\(entry.completedSets)/\(entry.totalSets) 组")
                            .font(.title3.bold())
                    }
                }
                
                Spacer()
                
                if let overview = entry.weekOverview {
                    Text("\(overview.trainingDays)练 · \(overview.totalSets)组")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let overview = entry.weekOverview {
                weekStrip(overview.weekDays, compact: true)
            }
            
            if !entry.isRestDay && !entry.isWorkoutComplete {
                ProgressView(value: entry.progress)
                    .tint(Color.accentColor)
            }
            
            if !entry.exercisePreview.isEmpty && !entry.isRestDay {
                Text(entry.exercisePreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
    }
    
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.isRestDay {
                Text("今日休息")
                    .font(.headline)
            } else if entry.isWorkoutComplete {
                Text("已完成 \(entry.completedSets) 组")
                    .font(.headline)
            } else {
                Text("\(entry.dayName) · \(entry.completedSets)/\(entry.totalSets) 组")
                    .font(.headline)
            }
            
            if entry.isRestDay, let nextDay = entry.nextWorkoutDayName {
                Text("下次 \(nextDay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !entry.isWorkoutComplete && !entry.isRestDay {
                ProgressView(value: entry.progress)
                    .tint(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var accessoryInlineView: some View {
        if entry.isRestDay {
            Text("休息")
        } else if entry.isWorkoutComplete {
            Text("已完成 \(entry.completedSets) 组")
        } else {
            Text("\(entry.dayName) \(entry.completedSets)/\(entry.totalSets)")
        }
    }
    
    @ViewBuilder
    private func weekStrip(_ days: [WeekPlanSummary.WeekDayDisplay], compact: Bool) -> some View {
        HStack(spacing: compact ? 2 : 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 2) {
                    Text(day.shortLabel)
                        .font(.system(size: compact ? 9 : 10, weight: day.isToday ? .bold : .regular))
                        .foregroundStyle(day.isToday ? Color.accentColor : .secondary)
                    
                    Circle()
                        .fill(day.isRestDay ? Color.green.opacity(0.7) : Color.accentColor.opacity(day.isToday ? 1 : 0.45))
                        .frame(width: compact ? 5 : 6, height: compact ? 5 : 6)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct FitnessAppWidget: Widget {
    let kind: String = "FitnessAppWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitnessAppWidgetProvider()) { entry in
            FitnessAppWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日训练")
        .description("查看本周课表与今日训练进度。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
