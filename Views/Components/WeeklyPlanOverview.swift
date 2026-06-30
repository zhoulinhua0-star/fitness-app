//
//  WeeklyPlanOverview.swift
//  FitnessApp
//

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
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(summaryLine)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                if let heaviestLine {
                    Text(heaviestLine)
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }

            weekStrip
        }
        .tiimoCard()
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(overview.weekDays.enumerated()), id: \.offset) { _, day in
                VStack(spacing: Theme.Spacing.xs) {
                    Text(day.shortLabel)
                        .font(.system(size: 11, weight: day.isToday ? .bold : .regular))
                        .foregroundStyle(day.isToday ? Theme.Color.accent : Theme.Color.textSecondary)

                    Text(day.focusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(day.isRestDay ? Theme.Color.success : Theme.Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if day.isRestDay {
                        Text(" ")
                            .font(.system(size: 9))
                    } else {
                        Text("\(day.totalSets)组")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
                .background(
                    day.isToday
                        ? Theme.Color.accentSoft
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
        }
    }
}
