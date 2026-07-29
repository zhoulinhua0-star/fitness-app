//
//  WeeklyPlanOverview.swift
//  FitnessApp
//

import SwiftUI

struct WeeklyPlanOverview: View {
    let overview: WeekPlanSummary.Overview

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showCalendar = false

    private var summaryLine: String {
        var parts = ["\(overview.trainingDays) 练", "\(overview.restDays) 休"]
        if overview.totalSets > 0 { parts.append("共 \(overview.totalSets) 组") }
        if let minutes = overview.totalCardioMinutes, minutes > 0 { parts.append("\(minutes) 分有氧") }
        return parts.joined(separator: " · ")
    }

    private var heaviestLine: String? {
        guard let name = overview.heaviestDayName, overview.heaviestDaySets > 0 else { return nil }
        return "最重：\(name) · \(overview.heaviestDaySets) 组"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(summaryLine)
                        .appScaledFont(size: 16, relativeTo: .body, weight: .semibold)
                        .foregroundStyle(Theme.Color.textPrimary)
                    if let heaviestLine {
                        Text(heaviestLine)
                            .font(.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }

                Spacer()

                Button {
                    showCalendar = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "calendar")
                        .appScaledFont(size: 15, relativeTo: .subheadline, weight: .semibold)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Theme.Color.surfaceMuted, in: Circle())
                        .contentShape(Rectangle().inset(by: -5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开训练日历")
            }

            weekStrip
        }
        .tiimoCard()
        .sheet(isPresented: $showCalendar) {
            WorkoutCalendarView()
                .presentationDragIndicator(.hidden)
        }
    }

    private var weekStrip: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    ForEach(Array(overview.weekDays.enumerated()), id: \.offset) { index, day in
                        HStack {
                            Text(day.shortLabel)
                                .font(.body.weight(day.isToday ? .bold : .regular))
                                .foregroundStyle(day.isToday ? Theme.Color.accent : Theme.Color.textSecondary)
                            Text(day.focusLabel)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(day.isRestDay ? Theme.Color.success : Theme.Color.textPrimary)
                            Spacer()
                            if !day.isRestDay {
                                Text(daySummary(day))
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.s)
                        if index < overview.weekDays.count - 1 {
                            Divider().background(Theme.Color.hairline)
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(overview.weekDays.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(day.shortLabel)
                                .appScaledFont(
                                    size: 11,
                                    relativeTo: .caption2,
                                    weight: day.isToday ? .bold : .regular
                                )
                                .foregroundStyle(day.isToday ? Theme.Color.accent : Theme.Color.textSecondary)

                            Text(day.focusLabel)
                                .appScaledFont(size: 11, relativeTo: .caption2, weight: .semibold)
                                .foregroundStyle(day.isRestDay ? Theme.Color.success : Theme.Color.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            if day.isRestDay {
                                Text(" ")
                                    .appScaledFont(size: 9, relativeTo: .caption2)
                            } else {
                                Text(daySummary(day))
                                    .appScaledFont(size: 9, relativeTo: .caption2, weight: .medium)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s)
                        .background(
                            day.isToday ? Theme.Color.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                }
            }
        }
    }

    private func daySummary(_ day: WeekPlanSummary.WeekDayDisplay) -> String {
        var parts: [String] = []
        if day.totalSets > 0 { parts.append("\(day.totalSets)组") }
        if let minutes = day.cardioMinutes, minutes > 0 { parts.append("\(minutes)分") }
        return parts.isEmpty ? "待定" : parts.joined(separator: "·")
    }
}
