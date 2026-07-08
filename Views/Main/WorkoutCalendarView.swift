//
//  WorkoutCalendarView.swift
//  FitnessApp
//
//  A Strong-style monthly training calendar. Reached from the calendar icon on
//  the weekly overview card. Days you trained get a soft grey circle; days you
//  fully completed get a green check badge. Today is a filled dark pill.
//

import SwiftUI
import SwiftData

struct WorkoutCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [WorkoutSession]

    @State private var displayedMonth: Date = .now

    /// Monday-first Gregorian calendar to match the app's 周一→周日 week model.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    /// Days with any logged sets → soft grey circle.
    private var trainedDates: Set<Date> {
        Set(sessions
            .filter { $0.completedSetCount > 0 }
            .map { calendar.startOfDay(for: $0.sessionDate) })
    }

    /// Days where the whole plan was finished → green check badge.
    private var completedDates: Set<Date> {
        Set(sessions
            .filter { $0.isComplete }
            .map { calendar.startOfDay(for: $0.sessionDate) })
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: displayedMonth)
    }

    private var monthCompletedCount: Int {
        completedDates.filter {
            calendar.isDate($0, equalTo: displayedMonth, toGranularity: .month)
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayHeader
            monthNav
            grid
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.l)
        .background(Theme.Color.surface.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text("训练日历")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Color.textPrimary)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Theme.Color.surfaceMuted,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.bottom, Theme.Spacing.l)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { s in
                Text(s)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, Theme.Spacing.s)
    }

    private var monthNav: some View {
        HStack {
            Text(monthTitle)
                .font(.display(22, weight: .bold))
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
            monthButton(systemName: "chevron.left") { changeMonth(-1) }
            monthButton(systemName: "chevron.right") { changeMonth(1) }
        }
        .padding(.vertical, Theme.Spacing.m)
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(width: 32, height: 32)
                .background(Theme.Color.surfaceMuted, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: Theme.Spacing.m
        ) {
            ForEach(Array(makeGrid().enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 46)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let start = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let trained = trainedDates.contains(start)
        let completed = completedDates.contains(start)
        let isFuture = start > calendar.startOfDay(for: .now)

        let circleFill: Color = isToday
            ? Theme.Color.cta
            : (trained ? Theme.Color.surfaceMuted : Color.clear)

        let textColor: Color = isToday
            ? Theme.Color.ctaLabel
            : (isFuture ? Theme.Color.textSecondary.opacity(0.55) : Theme.Color.textPrimary)

        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(circleFill)
                .frame(width: 40, height: 40)
                .overlay {
                    Text("\(day)")
                        .font(.system(size: 16, weight: isToday ? .bold : .medium))
                        .foregroundStyle(textColor)
                }

            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(Theme.Color.success, in: Circle())
                    .overlay(Circle().stroke(Theme.Color.surface, lineWidth: 2))
                    .offset(x: 5, y: -3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
            Text("本月完成 \(monthCompletedCount) 次训练")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.l)
    }

    // MARK: Helpers

    private func makeGrid() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstOfMonth) // 1=Sun … 7=Sat
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        return cells
    }

    private func changeMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) { displayedMonth = d }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
