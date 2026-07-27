import UIKit
import UserNotifications

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let content = notification.request.content

        if content.categoryIdentifier == NotificationManager.restTimerCategoryIdentifier,
           let timerID = content.userInfo["timerID"] as? String {
            let exerciseName = content.userInfo["exerciseName"] as? String ?? "当前动作"
            await MainActor.run {
                RestTimerCoordinator.shared.notificationDelivered(
                    timerID: timerID,
                    exerciseName: exerciseName
                )
            }
            return []
        }

        if notification.request.identifier.hasPrefix(NotificationManager.dailyReminderIdentifierPrefix) {
            return []
        }

        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content

        if response.notification.request.identifier.hasPrefix(
            NotificationManager.dailyReminderIdentifierPrefix
        ) {
            await MainActor.run {
                AppNavigation.shared.selectedTab = .today
            }
            return
        }

        guard content.categoryIdentifier == NotificationManager.restTimerCategoryIdentifier,
              let timerID = content.userInfo["timerID"] as? String else { return }

        await MainActor.run {
            AppNavigation.shared.openRestTimer(timerID)
        }
    }
}
