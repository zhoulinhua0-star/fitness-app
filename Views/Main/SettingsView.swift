import SwiftData
import SwiftUI

private enum PendingNotificationAction {
    case enableRestReminders
    case enableDailyReminders
    case sendTest
}

struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query private var workoutDays: [WorkoutDay]
    @State private var settings = AppSettings.shared
    @State private var authorizationState: NotificationAuthorizationState = .unknown
    @State private var notificationStatusMessage: String?
    @State private var pendingNotificationAction: PendingNotificationAction?
    @State private var showNotificationPermissionAlert = false
    @State private var waitingForNotificationSettings = false

    var body: some View {
        Form {
            Section {
                Toggle("休息结束提醒", isOn: $settings.restNotificationsEnabled)

                if settings.restNotificationsEnabled {
                    Toggle("声音", isOn: $settings.restSoundEnabled)
                    Toggle("触感反馈", isOn: $settings.restHapticsEnabled)

                    Button {
                        sendTestNotification()
                    } label: {
                        Label("发送测试提醒", systemImage: "bell.badge")
                    }
                }

                notificationPermissionRow
            } header: {
                Text("休息提醒")
            } footer: {
                Text("App 在前台时显示页内提醒；锁屏或退出 App 后由系统本地通知提醒。")
            }

            Section {
                Toggle("训练提醒", isOn: $settings.remindersEnabled)

                if settings.remindersEnabled {
                    DatePicker(
                        "提醒时间",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )

                    Toggle("仅在有训练计划的日期提醒", isOn: $settings.remindersOnPlannedDaysOnly)
                    Toggle("当天完成后不再提醒", isOn: $settings.skipReminderWhenCompleted)
                }

                if let notificationStatusMessage {
                    Label(notificationStatusMessage, systemImage: statusSymbol)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            } header: {
                Text("每日训练提醒")
            } footer: {
                Text("设置会自动保存。训练已经开始时，当天的计划提醒也会暂停。")
            }

        }
        .navigationTitle("通知与提醒")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reminderSettingsKey) {
            await refreshAuthorizationState()
            await refreshDailyReminders()
        }
        .onChange(of: settings.restNotificationsEnabled) { _, enabled in
            Task {
                if enabled {
                    let allowed = await NotificationManager.requestAuthorization()
                    if !allowed {
                        presentPermissionAlert(for: .enableRestReminders)
                    }
                }
                await refreshAuthorizationState()
                RestTimerCoordinator.shared.rescheduleSystemNotifications()
            }
        }
        .onChange(of: settings.remindersEnabled) { _, enabled in
            Task {
                await refreshDailyReminders(promptOnPermissionDenied: enabled)
            }
        }
        .onChange(of: settings.restSoundEnabled) { _, _ in
            RestTimerCoordinator.shared.rescheduleSystemNotifications()
        }
        .alert("通知权限未开启", isPresented: $showNotificationPermissionAlert) {
            Button("取消", role: .cancel) {
                pendingNotificationAction = nil
            }
            Button("前往系统设置") {
                openNotificationSettings()
            }
        } message: {
            Text("要接收休息结束和训练提醒，请在系统设置中允许 RepDay 发送通知。")
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if waitingForNotificationSettings {
                waitingForNotificationSettings = false
                resumePendingNotificationActionIfAllowed()
            } else {
                Task {
                    await refreshAuthorizationState()
                }
            }
        }
    }

    @ViewBuilder
    private var notificationPermissionRow: some View {
        HStack {
            Label("系统通知权限", systemImage: permissionSymbol)
            Spacer()
            Text(permissionLabel)
                .foregroundStyle(.secondary)
        }

        if authorizationState == .denied {
            Button("前往系统设置", action: openNotificationSettings)
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = settings.reminderHour
                components.minute = settings.reminderMinute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.reminderHour = components.hour ?? 19
                settings.reminderMinute = components.minute ?? 0
            }
        )
    }

    private var reminderSettingsKey: String {
        let planKey = workoutDays
            .sorted { $0.dayName < $1.dayName }
            .map { "\($0.dayName):\($0.isRestDay):\($0.exercises.count)" }
            .joined(separator: "|")
        return [
            planKey,
            String(settings.reminderHour),
            String(settings.reminderMinute),
            String(settings.remindersOnPlannedDaysOnly),
            String(settings.skipReminderWhenCompleted),
            settings.languagePreference.rawValue
        ].joined(separator: "#")
    }

    private func refreshAuthorizationState() async {
        authorizationState = await NotificationManager.authorizationState()
    }

    private func refreshDailyReminders(promptOnPermissionDenied: Bool = false) async {
        let todayName = WorkoutHistoryManager.todayWeekdayString()
        let todayExercises = workoutDays.first(where: { $0.dayName == todayName })?.exercises ?? []
        let completedToday = !todayExercises.isEmpty && todayExercises.allSatisfy(\.isFullyCompletedToday)
        let isWorkoutActive = RestTimerCoordinator.shared.activeCount > 0 ||
            todayExercises.contains { $0.effectiveCompletedSetCount > 0 && !$0.isFullyCompletedToday }
        let snapshots = workoutDays.map {
            WorkoutDayReminderSnapshot(
                dayName: $0.dayName,
                hasWorkout: !$0.isRestDay && !$0.exercises.isEmpty
            )
        }

        let result = await NotificationManager.refreshDailyReminders(
            settings: settings,
            workoutDays: snapshots,
            completedToday: completedToday,
            isWorkoutActive: isWorkoutActive
        )
        notificationStatusMessage = message(for: result)
        await refreshAuthorizationState()
        if result == .permissionDenied, promptOnPermissionDenied {
            presentPermissionAlert(for: .enableDailyReminders)
        }
    }

    private func sendTestNotification() {
        Task {
            let result = await NotificationManager.scheduleTestNotification(
                playsSound: settings.restSoundEnabled
            )
            notificationStatusMessage = switch result {
            case .scheduled: AppLocalization.string("测试提醒将在 3 秒后显示")
            case .permissionDenied: AppLocalization.string("系统通知权限未开启")
            case .failed: AppLocalization.string("测试提醒未能创建，请稍后重试")
            case .disabled, .noPlannedDays: nil
            }
            await refreshAuthorizationState()
            if result == .permissionDenied {
                presentPermissionAlert(for: .sendTest)
            }
        }
    }

    private func presentPermissionAlert(for action: PendingNotificationAction) {
        pendingNotificationAction = action
        showNotificationPermissionAlert = true
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        waitingForNotificationSettings = true
        openURL(url)
    }

    private func resumePendingNotificationActionIfAllowed() {
        Task {
            await refreshAuthorizationState()
            guard authorizationState == .allowed else {
                pendingNotificationAction = nil
                return
            }

            let action = pendingNotificationAction
            pendingNotificationAction = nil
            switch action {
            case .enableRestReminders:
                RestTimerCoordinator.shared.rescheduleSystemNotifications()
                notificationStatusMessage = AppLocalization.string("系统通知权限已开启")
            case .enableDailyReminders:
                await refreshDailyReminders()
            case .sendTest:
                sendTestNotification()
            case nil:
                break
            }
        }
    }

    private func message(for result: NotificationScheduleResult) -> String? {
        switch result {
        case .scheduled:
            return AppLocalization.string("训练提醒已自动更新")
        case .disabled:
            return AppLocalization.string("训练提醒已关闭")
        case .noPlannedDays:
            return settings.remindersOnPlannedDaysOnly
                ? AppLocalization.string("当前没有可提醒的训练日")
                : nil
        case .permissionDenied:
            return AppLocalization.string("系统通知权限未开启")
        case .failed:
            return AppLocalization.string("提醒更新失败，请稍后重试")
        }
    }

    private var permissionLabel: String {
        switch authorizationState {
        case .allowed: AppLocalization.string("已允许")
        case .denied: AppLocalization.string("未允许")
        case .notDetermined: AppLocalization.string("尚未请求")
        case .unknown: AppLocalization.string("检查中")
        }
    }

    private var permissionSymbol: String {
        switch authorizationState {
        case .allowed: "checkmark.circle.fill"
        case .denied: "exclamationmark.circle.fill"
        case .notDetermined, .unknown: "circle.dotted"
        }
    }

    private var statusSymbol: String {
        [
            AppLocalization.string("系统通知权限未开启"),
            AppLocalization.string("测试提醒未能创建，请稍后重试"),
            AppLocalization.string("提醒更新失败，请稍后重试")
        ].contains(notificationStatusMessage)
            ? "exclamationmark.circle"
            : "checkmark.circle"
    }

    private var statusColor: Color {
        statusSymbol == "exclamationmark.circle" ? Theme.Color.accent : Theme.Color.textSecondary
    }

}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .modelContainer(for: [WorkoutDay.self, Exercise.self], inMemory: true)
}
