//
//  RootView.swift
//  FitnessApp
//
//  Hosts the launch sequence: SplashView sits on top of MainTabView and, once
//  finished, slides/fades up to reveal the main content. Because `showSplash`
//  flips to false, the splash leaves the view hierarchy and is freed.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize
    @Query private var workoutDays: [WorkoutDay]
    @Query(filter: #Predicate<Exercise> { $0.isImprov }) private var improvExercises: [Exercise]
    @AppStorage("improvFinishedDayStamp") private var improvFinishedDayStamp: Double = 0
    @State private var showSplash = true
    @State private var restTimers = RestTimerCoordinator.shared
    @State private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            MainTabView()

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSplash = false
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

            if !showSplash, let notice = restTimers.notice {
                VStack {
                    RestTimerNoticeBanner(notice: notice) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            restTimers.dismissNotice()
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .dynamicTypeSize(settings.textSizePreference.adjusted(from: systemDynamicTypeSize))
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: restTimers.notice)
        .task(id: reminderRefreshKey) {
            await refreshDailyReminders()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            restTimers.rescheduleSystemNotifications()
        }
    }

    private var todayExercises: [Exercise] {
        let todayImprov = improvExercises.filter {
            $0.sessionDate.map { Calendar.current.isDateInToday($0) } ?? false
        }
        if !todayImprov.isEmpty {
            return todayImprov
        }
        let todayName = WorkoutHistoryManager.todayWeekdayString()
        return workoutDays.first(where: { $0.dayName == todayName })?.exercises ?? []
    }

    private var completedToday: Bool {
        if improvFinishedDayStamp == WorkoutHistoryManager.startOfDay().timeIntervalSince1970 {
            return true
        }
        let exercises = todayExercises.filter { !$0.isRemovedFromImprov }
        return !exercises.isEmpty && exercises.allSatisfy(\.isFullyCompletedToday)
    }

    private var isWorkoutActive: Bool {
        restTimers.activeCount > 0 ||
            todayExercises.contains { $0.effectiveCompletedSetCount > 0 && !$0.isFullyCompletedToday }
    }

    private var reminderRefreshKey: String {
        let planKey = workoutDays
            .sorted { $0.dayName < $1.dayName }
            .map { "\($0.dayName):\($0.isRestDay):\($0.exercises.count)" }
            .joined(separator: "|")
        return [
            planKey,
            String(settings.remindersEnabled),
            String(settings.reminderHour),
            String(settings.reminderMinute),
            String(settings.remindersOnPlannedDaysOnly),
            String(settings.skipReminderWhenCompleted),
            String(completedToday),
            String(isWorkoutActive),
            String(scenePhase == .active)
        ].joined(separator: "#")
    }

    private func refreshDailyReminders() async {
        let snapshots = workoutDays.map {
            WorkoutDayReminderSnapshot(
                dayName: $0.dayName,
                hasWorkout: !$0.isRestDay && !$0.exercises.isEmpty
            )
        }
        _ = await NotificationManager.refreshDailyReminders(
            settings: settings,
            workoutDays: snapshots,
            completedToday: completedToday,
            isWorkoutActive: isWorkoutActive
        )
    }
}

private struct RestTimerNoticeBanner: View {
    let notice: RestTimerNotice
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: notice.kind == .completed ? "checkmark.circle.fill" : "bell.slash.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(notice.kind == .completed ? Theme.Color.success : Theme.Color.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(notice.message)
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: Theme.Spacing.s)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭提醒")
        }
        .padding(.leading, Theme.Spacing.l)
        .padding(.trailing, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.s)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .stroke(Theme.Color.hairline, lineWidth: 1)
        )
        .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [WorkoutDay.self, Exercise.self, WorkoutSession.self, SetLog.self], inMemory: true)
}
