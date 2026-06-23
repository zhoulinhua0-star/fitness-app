import WidgetKit
import SwiftUI

struct FitnessAppWidgetEntry: TimelineEntry {
    let date: Date
    let completedSets: Int
    let totalSets: Int
    let completedExercises: Int
    let totalExercises: Int
    let dayName: String
    
    var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
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
            dayName: "周三"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FitnessAppWidgetEntry) -> Void) {
        completion(makeEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FitnessAppWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    private func makeEntry() -> FitnessAppWidgetEntry {
        FitnessAppWidgetEntry(
            date: .now,
            completedSets: WidgetDataStore.completedSets,
            totalSets: WidgetDataStore.totalSets,
            completedExercises: WidgetDataStore.completedExercises,
            totalExercises: WidgetDataStore.totalExercises,
            dayName: WidgetDataStore.dayName
        )
    }
}

struct FitnessAppWidgetEntryView: View {
    var entry: FitnessAppWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(Color.accentColor)
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
                .tint(.accentColor)
            
            Text("\(entry.completedExercises)/\(entry.totalExercises) 个动作")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
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
        .description("查看今日训练组数与动作完成进度。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
