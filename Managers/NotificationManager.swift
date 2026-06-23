import Foundation
import UserNotifications

enum NotificationManager {
    static let reminderIdentifier = "dailyWorkoutReminder"
    static let restTimerEndIdentifier = "restTimerEnd"
    
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    static func scheduleDailyReminder(settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        
        guard settings.remindersEnabled else { return }
        
        let granted = await requestAuthorization()
        guard granted else { return }
        
        var components = DateComponents()
        components.hour = settings.reminderHour
        components.minute = settings.reminderMinute
        
        let content = UNMutableNotificationContent()
        content.title = "训练提醒"
        content.body = "今天的训练还没完成，打开 App 继续打卡吧！"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
    
    static func scheduleRestEndNotification(after seconds: Int, exerciseName: String) {
        guard seconds > 0 else { return }
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restTimerEndIdentifier])
        
        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "\(exerciseName) — 可以开始下一组了"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: restTimerEndIdentifier,
            content: content,
            trigger: trigger
        )
        
        Task {
            _ = await requestAuthorization()
            try? await center.add(request)
        }
    }
    
    static func cancelRestEndNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [restTimerEndIdentifier])
    }
}
