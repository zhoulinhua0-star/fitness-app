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
            let exerciseName = content.userInfo["exerciseName"] as? String
                ?? AppLocalization.string("当前动作")
            await MainActor.run {
                RestTimerCoordinator.shared.notificationDelivered(
                    timerID: timerID,
                    exerciseName: exerciseName
                )
            }
            return []
        }

        if content.categoryIdentifier == NotificationManager.cardioGoalCategoryIdentifier,
           let timerID = content.userInfo["timerID"] as? String {
            let exerciseName = content.userInfo["exerciseName"] as? String
                ?? AppLocalization.string("当前动作")
            let targetDurationSeconds =
                (content.userInfo["targetDurationSeconds"] as? NSNumber)?.intValue ??
                content.userInfo["targetDurationSeconds"] as? Int ??
                0
            await MainActor.run {
                CardioGoalCoordinator.shared.notificationDelivered(
                    timerID: timerID,
                    exerciseName: exerciseName,
                    targetDurationSeconds: targetDurationSeconds
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

        guard let timerID = content.userInfo["timerID"] as? String else { return }

        await MainActor.run {
            if content.categoryIdentifier == NotificationManager.cardioGoalCategoryIdentifier {
                CardioGoalCoordinator.shared.notificationOpened(timerID: timerID)
            }
            guard content.categoryIdentifier == NotificationManager.restTimerCategoryIdentifier ||
                    content.categoryIdentifier == NotificationManager.cardioGoalCategoryIdentifier else {
                return
            }
            AppNavigation.shared.openTimerExercise(timerID)
        }
    }
}
