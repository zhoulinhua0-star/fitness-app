import Foundation
import UserNotifications

enum NotificationAuthorizationState: Equatable {
    case unknown
    case notDetermined
    case allowed
    case denied
}

enum NotificationScheduleResult: Equatable {
    case scheduled
    case disabled
    case noPlannedDays
    case permissionDenied
    case failed
}

struct WorkoutDayReminderSnapshot: Sendable {
    let dayName: String
    let hasWorkout: Bool
}

enum NotificationManager {
    static let dailyReminderIdentifierPrefix = "dailyWorkoutReminder."
    static let restTimerCategoryIdentifier = "restTimer"
    static let testCategoryIdentifier = "notificationTest"

    private static let legacyReminderIdentifier = "dailyWorkoutReminder"
    private static let restTimerEndIdentifierPrefix = "restTimerEnd."
    private static let legacyRestTimerEndIdentifier = "restTimerEnd"

    static func authorizationState() async -> NotificationAuthorizationState {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }

    static func requestAuthorization() async -> Bool {
        switch await authorizationState() {
        case .allowed:
            return true
        case .denied:
            return false
        case .notDetermined, .unknown:
            do {
                return try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        }
    }

    static func refreshDailyReminders(
        settings: AppSettings,
        workoutDays: [WorkoutDayReminderSnapshot],
        completedToday: Bool,
        isWorkoutActive: Bool
    ) async -> NotificationScheduleResult {
        let center = UNUserNotificationCenter.current()
        await removePendingRequests(withPrefix: dailyReminderIdentifierPrefix)
        center.removePendingNotificationRequests(withIdentifiers: [legacyReminderIdentifier])

        guard settings.remindersEnabled else { return .disabled }
        guard await requestAuthorization() else { return .permissionDenied }

        let calendar = Calendar.current
        let now = Date()
        let plansByName = Dictionary(uniqueKeysWithValues: workoutDays.map { ($0.dayName, $0) })
        var requests: [UNNotificationRequest] = []

        for dayOffset in 0..<21 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let dayName = WorkoutHistoryManager.todayWeekdayString(from: date)
            let hasPlan = plansByName[dayName]?.hasWorkout == true
            guard !settings.remindersOnPlannedDaysOnly || hasPlan else { continue }

            if dayOffset == 0 {
                if isWorkoutActive { continue }
                if settings.skipReminderWhenCompleted && completedToday { continue }
            }

            var triggerComponents = calendar.dateComponents([.year, .month, .day], from: date)
            triggerComponents.hour = settings.reminderHour
            triggerComponents.minute = settings.reminderMinute
            guard let fireDate = calendar.date(from: triggerComponents), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "训练提醒"
            content.body = hasPlan
                ? "\(dayName)的训练还没完成，准备好就开始吧。"
                : "今天想动一动吗？打开 RepDay 开始训练。"
            content.sound = .default
            content.threadIdentifier = "dailyWorkoutReminders"

            let identifier = dailyReminderIdentifierPrefix + dateIdentifier(for: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            requests.append(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            ))
        }

        guard !requests.isEmpty else { return .noPlannedDays }

        do {
            for request in requests {
                try await center.add(request)
            }
            return .scheduled
        } catch {
            await removePendingRequests(withPrefix: dailyReminderIdentifierPrefix)
            return .failed
        }
    }

    static func cancelDailyReminder(for date: Date = .now) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyReminderIdentifierPrefix + dateIdentifier(for: date)]
        )
    }

    static func scheduleRestEndNotification(
        after seconds: Int,
        exerciseName: String,
        timerID: String,
        playsSound: Bool
    ) async -> NotificationScheduleResult {
        guard seconds > 0 else { return .failed }
        guard await requestAuthorization() else { return .permissionDenied }

        let center = UNUserNotificationCenter.current()
        let identifier = restTimerEndIdentifier(for: timerID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "\(exerciseName) · 可以开始下一组了"
        content.sound = playsSound ? .default : nil
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = restTimerCategoryIdentifier
        content.threadIdentifier = "restTimers"
        content.userInfo = [
            "timerID": timerID,
            "exerciseName": exerciseName
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return .scheduled
        } catch {
            return .failed
        }
    }

    static func scheduleTestNotification(playsSound: Bool) async -> NotificationScheduleResult {
        guard await requestAuthorization() else { return .permissionDenied }

        let content = UNMutableNotificationContent()
        content.title = "测试提醒"
        content.body = "通知工作正常，你可以放心开始训练。"
        content.sound = playsSound ? .default : nil
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = testCategoryIdentifier

        let request = UNNotificationRequest(
            identifier: "notificationTest.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return .scheduled
        } catch {
            return .failed
        }
    }

    static func cancelRestEndNotification(timerID: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [restTimerEndIdentifier(for: timerID)]
            )
    }

    static func cancelLegacyRestEndNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [legacyRestTimerEndIdentifier])
    }

    private static func restTimerEndIdentifier(for timerID: String) -> String {
        restTimerEndIdentifierPrefix + timerID
    }

    private static func dateIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func removePendingRequests(withPrefix prefix: String) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
