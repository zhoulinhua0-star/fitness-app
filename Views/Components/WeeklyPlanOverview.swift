import SwiftUI

struct WeeklyPlanOverview: View {
    let overview: WeekPlanSummary.Overview
    
    private var summaryLine: String {
        "\(overview.trainingDays) 练 · \(overview.restDays) 休 · 共 \(overview.totalSets) 组"
    }
    
    private var heaviestLine: String? {
        guard let name = overview.heaviestDayName, overview.heaviestDaySets > 0 else { return nil }
        return "最重：\(name) · \(overview.heaviestDaySets) 组"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summaryLine)
                    .font(.headline)
                if let heaviestLine {
                    Text(heaviestLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            weekStrip
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(overview.weekDays.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 4) {
                    Text(day.shortLabel)
                        .font(.caption2.weight(day.isToday ? .bold : .regular))
                        .foregroundStyle(day.isToday ? Color.accentColor : .secondary)
                    
                    Text(day.focusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(day.isRestDay ? .green : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if day.isRestDay {
                        Text(" ")
                            .font(.system(size: 9))
                    } else {
                        Text("\(day.totalSets)组")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(day.isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                )
            }
        }
    }
}
