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

struct RestTimerNotice: Equatable, Identifiable {
    enum Kind: Equatable {
        case completed
        case warning
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}

@MainActor
@Observable
final class RestTimerCoordinator {
    static let shared = RestTimerCoordinator()

    private static let endDatesKey = "restTimerEndDates"
    private static let exerciseNamesKey = "restTimerExerciseNames"

    private(set) var timers: [String: ActiveRestTimer] = [:]
    private(set) var notice: RestTimerNotice?

    private var tickerTask: Task<Void, Never>?
    private var noticeDismissTask: Task<Void, Never>?
    private var queuedNotices: [RestTimerNotice] = []

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
        timers[timerID] = ActiveRestTimer(
            id: timerID,
            exerciseName: exerciseName,
            endDate: endDate
        )
        persistTimers()
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
        persistTimers()
        NotificationManager.cancelRestEndNotification(timerID: timerID)
    }

    func notificationDelivered(timerID: String, exerciseName: String) {
        guard timers.removeValue(forKey: timerID) != nil else { return }
        persistTimers()
        presentCompletion(for: exerciseName)
    }

    func rescheduleSystemNotifications() {
        for timer in timers.values where timer.endDate > .now {
            scheduleSystemNotification(for: timer)
        }
    }

    func dismissNotice() {
        noticeDismissTask?.cancel()
        notice = nil
        showNextNoticeIfNeeded()
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
                presentNotice(
                    kind: .warning,
                    title: "系统通知未开启",
                    message: "留在 App 内仍会提醒；锁屏或退出 App 时请先开启通知权限。"
                )
            case .failed:
                presentNotice(
                    kind: .warning,
                    title: "系统提醒创建失败",
                    message: "App 内计时仍会继续，请稍后在通知设置中重试。"
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
        let now = Date()

        timers = storedDates.reduce(into: [:]) { result, entry in
            guard let number = entry.value as? NSNumber else { return }
            let endDate = Date(timeIntervalSince1970: number.doubleValue)
            guard endDate > now else { return }
            result[entry.key] = ActiveRestTimer(
                id: entry.key,
                exerciseName: storedNames[entry.key] ?? "当前动作",
                endDate: endDate
            )
        }
        persistTimers()
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
            NotificationManager.cancelRestEndNotification(timerID: timer.id)
        }
        persistTimers()

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
        presentNotice(
            kind: .completed,
            title: "休息结束",
            message: "\(exerciseName) · 可以开始下一组了"
        )
    }

    private func presentNotice(kind: RestTimerNotice.Kind, title: String, message: String) {
        let newNotice = RestTimerNotice(kind: kind, title: title, message: message)
        guard notice == nil else {
            queuedNotices.append(newNotice)
            return
        }
        show(newNotice)
    }

    private func show(_ newNotice: RestTimerNotice) {
        notice = newNotice
        noticeDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.notice = nil
            self?.showNextNoticeIfNeeded()
        }
    }

    private func showNextNoticeIfNeeded() {
        guard notice == nil, !queuedNotices.isEmpty else { return }
        show(queuedNotices.removeFirst())
    }
}
