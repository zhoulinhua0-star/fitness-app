import AudioToolbox
import Foundation
import Observation
import SwiftData
import UIKit

struct ActiveCardioGoalTimer: Equatable {
    let id: String
    var exerciseName: String
    var targetDurationSeconds: Int
    var endDate: Date
}

@MainActor
@Observable
final class CardioGoalCoordinator {
    static let shared = CardioGoalCoordinator()

    private(set) var timers: [String: ActiveCardioGoalTimer] = [:]

    private var tickerTask: Task<Void, Never>?

    private init() {}

    var activeCount: Int {
        timers.values.filter { $0.endDate > .now }.count
    }

    func start(
        timerID: String,
        exerciseName: String,
        targetDurationSeconds: Int,
        elapsedSeconds: Int
    ) {
        let remainingSeconds = targetDurationSeconds - elapsedSeconds
        guard remainingSeconds > 0 else {
            cancel(timerID: timerID)
            return
        }

        let timer = ActiveCardioGoalTimer(
            id: timerID,
            exerciseName: exerciseName,
            targetDurationSeconds: targetDurationSeconds,
            endDate: Date().addingTimeInterval(TimeInterval(remainingSeconds))
        )
        timers[timerID] = timer
        ensureTicker()
        scheduleSystemNotification(for: timer)
    }

    func pause(timerID: String) {
        cancel(timerID: timerID)
    }

    func cancel(timerID: String) {
        timers.removeValue(forKey: timerID)
        NotificationManager.cancelCardioGoalNotification(timerID: timerID)
    }

    func reconcile(exercises: [Exercise], now: Date = .now) {
        for exercise in exercises where
            exercise.isCardio &&
            exercise.cardioStartedAt != nil &&
            !exercise.isFullyCompletedToday {
            start(
                timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID),
                exerciseName: exercise.name,
                targetDurationSeconds: exercise.targetDurationSeconds,
                elapsedSeconds: exercise.cardioElapsedSeconds(at: now)
            )
        }
    }

    func notificationDelivered(
        timerID: String,
        exerciseName: String,
        targetDurationSeconds: Int
    ) {
        timers.removeValue(forKey: timerID)
        guard AppSettings.shared.cardioGoalNotificationsEnabled else { return }
        presentGoal(
            exerciseName: exerciseName,
            targetDurationSeconds: targetDurationSeconds
        )
    }

    func notificationOpened(timerID: String) {
        timers.removeValue(forKey: timerID)
    }

    func rescheduleSystemNotifications() {
        for timer in timers.values where timer.endDate > .now {
            scheduleSystemNotification(for: timer)
        }
    }

    private func scheduleSystemNotification(for timer: ActiveCardioGoalTimer) {
        guard AppSettings.shared.cardioGoalNotificationsEnabled else {
            NotificationManager.cancelCardioGoalNotification(timerID: timer.id)
            return
        }

        let remaining = max(1, Int(timer.endDate.timeIntervalSinceNow.rounded(.up)))
        Task {
            let result = await NotificationManager.scheduleCardioGoalNotification(
                after: remaining,
                exerciseName: timer.exerciseName,
                timerID: timer.id,
                targetDurationSeconds: timer.targetDurationSeconds,
                playsSound: AppSettings.shared.restSoundEnabled
            )
            switch result {
            case .permissionDenied:
                WorkoutTimerNoticeCenter.shared.present(
                    kind: .warning,
                    title: AppLocalization.string("系统通知未开启"),
                    message: AppLocalization.string("留在 App 内仍会提醒；锁屏或退出 App 时请先开启通知权限。")
                )
            case .failed:
                WorkoutTimerNoticeCenter.shared.present(
                    kind: .warning,
                    title: AppLocalization.string("系统提醒创建失败"),
                    message: AppLocalization.string("App 内计时仍会继续，请稍后在通知设置中重试。")
                )
            case .scheduled, .disabled, .noPlannedDays:
                break
            }
        }
    }

    private func ensureTicker() {
        guard !timers.isEmpty, tickerTask == nil else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.finishExpiredTimers()
                if self.timers.isEmpty {
                    self.tickerTask = nil
                    return
                }
            }
        }
    }

    private func finishExpiredTimers() {
        guard UIApplication.shared.applicationState == .active else { return }

        let now = Date()
        let expired = timers.values.filter { $0.endDate <= now }
        guard !expired.isEmpty else { return }

        for timer in expired {
            timers.removeValue(forKey: timer.id)
            NotificationManager.cancelCardioGoalNotification(timerID: timer.id)
        }

        guard AppSettings.shared.cardioGoalNotificationsEnabled else { return }
        for timer in expired where now.timeIntervalSince(timer.endDate) < 3 {
            presentGoal(
                exerciseName: timer.exerciseName,
                targetDurationSeconds: timer.targetDurationSeconds
            )
        }
    }

    private func presentGoal(exerciseName: String, targetDurationSeconds: Int) {
        if AppSettings.shared.restHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if AppSettings.shared.restSoundEnabled {
            AudioServicesPlaySystemSound(1007)
        }
        WorkoutTimerNoticeCenter.shared.present(
            kind: .cardioGoal,
            title: AppLocalization.string("有氧目标已达到"),
            message: AppLocalization.format(
                "%@ · 已完成 %@，可以继续或返回 RepDay 保存。",
                ExerciseLibrary.displayName(for: exerciseName),
                ExerciseFormatting.shortDuration(targetDurationSeconds)
            )
        )
    }
}
