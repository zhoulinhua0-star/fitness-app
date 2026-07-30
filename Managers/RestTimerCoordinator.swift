import AudioToolbox
import Foundation
import Observation
import SwiftData
import UIKit

struct ActiveRestTimer: Equatable {
    let id: String
    var exerciseName: String
    var endDate: Date
}

enum RestCompletionReason: String, Equatable {
    case elapsed
    case skipped
}

struct CompletedRestTimer: Equatable {
    let id: String
    let completedAt: Date
    let reason: RestCompletionReason
}

@MainActor
@Observable
final class RestTimerCoordinator {
    static let shared = RestTimerCoordinator()

    private static let endDatesKey = "restTimerEndDates"
    private static let exerciseNamesKey = "restTimerExerciseNames"
    private static let completedDatesKey = "restTimerCompletedDates"
    private static let completionReasonsKey = "restTimerCompletionReasons"

    private(set) var timers: [String: ActiveRestTimer] = [:]
    private(set) var completions: [String: CompletedRestTimer] = [:]

    private var tickerTask: Task<Void, Never>?

    private init() {
        restorePersistedTimers()
        ensureTicker()
    }

    static func timerID(for persistentModelID: PersistentIdentifier) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(persistentModelID).base64EncodedString())
            ?? String(describing: persistentModelID)
    }

    var activeCount: Int {
        timers.values.filter { $0.endDate > .now }.count
    }

    func timer(for id: String) -> ActiveRestTimer? {
        guard let timer = timers[id], timer.endDate > .now else { return nil }
        return timer
    }

    func completion(for id: String, now: Date = .now) -> CompletedRestTimer? {
        if let completion = completions[id],
           Calendar.current.isDate(completion.completedAt, inSameDayAs: now) {
            return completion
        }

        guard let timer = timers[id],
              timer.endDate <= now,
              Calendar.current.isDate(timer.endDate, inSameDayAs: now) else {
            return nil
        }
        return CompletedRestTimer(id: id, completedAt: timer.endDate, reason: .elapsed)
    }

    func register(timerID: String, exerciseName: String) {
        guard var timer = timers[timerID] else { return }
        guard timer.exerciseName != exerciseName else { return }
        timer.exerciseName = exerciseName
        timers[timerID] = timer
        persistTimers()
    }

    func start(timerID: String, exerciseName: String, seconds: Int) {
        let endDate = Date().addingTimeInterval(TimeInterval(seconds))
        setTimer(timerID: timerID, exerciseName: exerciseName, endDate: endDate)
    }

    func restore(timerID: String, exerciseName: String, endDate: Date) {
        guard endDate > .now else { return }
        setTimer(timerID: timerID, exerciseName: exerciseName, endDate: endDate)
    }

    private func setTimer(timerID: String, exerciseName: String, endDate: Date) {
        completions.removeValue(forKey: timerID)
        timers[timerID] = ActiveRestTimer(
            id: timerID,
            exerciseName: exerciseName,
            endDate: endDate
        )
        persistTimers()
        persistCompletions()
        ensureTicker()
        scheduleSystemNotification(for: timers[timerID]!)
    }

    func adjust(timerID: String, endDate: Date) {
        guard var timer = timers[timerID] else { return }
        timer.endDate = max(endDate, Date().addingTimeInterval(1))
        timers[timerID] = timer
        persistTimers()
        scheduleSystemNotification(for: timer)
    }

    func cancel(timerID: String) {
        timers.removeValue(forKey: timerID)
        completions.removeValue(forKey: timerID)
        persistTimers()
        persistCompletions()
        NotificationManager.cancelRestEndNotification(timerID: timerID)
    }

    func skip(timerID: String) {
        guard timers.removeValue(forKey: timerID) != nil else { return }
        completions[timerID] = CompletedRestTimer(
            id: timerID,
            completedAt: .now,
            reason: .skipped
        )
        persistTimers()
        persistCompletions()
        NotificationManager.cancelRestEndNotification(timerID: timerID)
    }

    func notificationDelivered(timerID: String, exerciseName: String) {
        guard let timer = timers.removeValue(forKey: timerID) else { return }
        completions[timerID] = CompletedRestTimer(
            id: timerID,
            completedAt: timer.endDate,
            reason: .elapsed
        )
        persistTimers()
        persistCompletions()
        presentCompletion(for: exerciseName)
    }

    func rescheduleSystemNotifications() {
        for timer in timers.values where timer.endDate > .now {
            scheduleSystemNotification(for: timer)
        }
    }

    private func scheduleSystemNotification(for timer: ActiveRestTimer) {
        guard AppSettings.shared.restNotificationsEnabled else {
            NotificationManager.cancelRestEndNotification(timerID: timer.id)
            return
        }

        let remaining = max(1, Int(timer.endDate.timeIntervalSinceNow.rounded(.up)))
        Task {
            let result = await NotificationManager.scheduleRestEndNotification(
                after: remaining,
                exerciseName: timer.exerciseName,
                timerID: timer.id,
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

    private func restorePersistedTimers() {
        let defaults = UserDefaults.standard
        let storedDates = defaults.dictionary(forKey: Self.endDatesKey) ?? [:]
        let storedNames = defaults.dictionary(forKey: Self.exerciseNamesKey) as? [String: String] ?? [:]
        let storedCompletedDates = defaults.dictionary(forKey: Self.completedDatesKey) ?? [:]
        let storedCompletionReasons = defaults.dictionary(forKey: Self.completionReasonsKey) as? [String: String] ?? [:]
        let now = Date()

        completions = storedCompletedDates.reduce(into: [:]) { result, entry in
            guard let number = entry.value as? NSNumber else { return }
            let completedAt = Date(timeIntervalSince1970: number.doubleValue)
            guard Calendar.current.isDate(completedAt, inSameDayAs: now) else { return }
            let reason = storedCompletionReasons[entry.key]
                .flatMap(RestCompletionReason.init(rawValue:)) ?? .elapsed
            result[entry.key] = CompletedRestTimer(
                id: entry.key,
                completedAt: completedAt,
                reason: reason
            )
        }

        timers = storedDates.reduce(into: [:]) { result, entry in
            guard let number = entry.value as? NSNumber else { return }
            let endDate = Date(timeIntervalSince1970: number.doubleValue)
            if endDate > now {
                result[entry.key] = ActiveRestTimer(
                    id: entry.key,
                    exerciseName: storedNames[entry.key] ?? AppLocalization.string("当前动作"),
                    endDate: endDate
                )
            } else if Calendar.current.isDate(endDate, inSameDayAs: now),
                      completions[entry.key] == nil {
                completions[entry.key] = CompletedRestTimer(
                    id: entry.key,
                    completedAt: endDate,
                    reason: .elapsed
                )
            }
        }
        persistTimers()
        persistCompletions()
    }

    private func persistTimers() {
        if timers.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.endDatesKey)
            UserDefaults.standard.removeObject(forKey: Self.exerciseNamesKey)
            return
        }

        UserDefaults.standard.set(
            timers.mapValues { $0.endDate.timeIntervalSince1970 },
            forKey: Self.endDatesKey
        )
        UserDefaults.standard.set(
            timers.mapValues(\.exerciseName),
            forKey: Self.exerciseNamesKey
        )
    }

    private func persistCompletions() {
        let todayCompletions = completions.filter {
            Calendar.current.isDateInToday($0.value.completedAt)
        }
        if todayCompletions.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.completedDatesKey)
            UserDefaults.standard.removeObject(forKey: Self.completionReasonsKey)
            return
        }

        UserDefaults.standard.set(
            todayCompletions.mapValues { $0.completedAt.timeIntervalSince1970 },
            forKey: Self.completedDatesKey
        )
        UserDefaults.standard.set(
            todayCompletions.mapValues { $0.reason.rawValue },
            forKey: Self.completionReasonsKey
        )
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
        // Keep pending local notifications intact while the app is backgrounded.
        // iOS owns delivery there; the in-app coordinator resumes cleanup later.
        guard UIApplication.shared.applicationState == .active else { return }

        let now = Date()
        let expired = timers.values.filter { $0.endDate <= now }
        guard !expired.isEmpty else { return }

        for timer in expired {
            timers.removeValue(forKey: timer.id)
            completions[timer.id] = CompletedRestTimer(
                id: timer.id,
                completedAt: timer.endDate,
                reason: .elapsed
            )
            NotificationManager.cancelRestEndNotification(timerID: timer.id)
        }
        persistTimers()
        persistCompletions()

        guard AppSettings.shared.restNotificationsEnabled else { return }

        // A timer that expired while the app was away was already handled by
        // the system notification. Only announce freshly elapsed foreground timers.
        for timer in expired where now.timeIntervalSince(timer.endDate) < 3 {
            presentCompletion(for: timer.exerciseName)
        }
    }

    private func presentCompletion(for exerciseName: String) {
        if AppSettings.shared.restHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if AppSettings.shared.restSoundEnabled {
            AudioServicesPlaySystemSound(1007)
        }
        WorkoutTimerNoticeCenter.shared.present(
            kind: .completed,
            title: AppLocalization.string("休息结束"),
            message: AppLocalization.format(
                "%@ · 可以开始下一组了",
                ExerciseLibrary.displayName(for: exerciseName)
            )
        )
    }

}
