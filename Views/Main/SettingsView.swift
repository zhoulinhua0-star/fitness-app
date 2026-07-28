import SwiftData
import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Query private var workoutDays: [WorkoutDay]
    @State private var settings = AppSettings.shared
    @State private var authorizationState: NotificationAuthorizationState = .unknown
    @State private var notificationStatusMessage: String?

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
                    _ = await NotificationManager.requestAuthorization()
                }
                await refreshAuthorizationState()
                RestTimerCoordinator.shared.rescheduleSystemNotifications()
            }
        }
        .onChange(of: settings.restSoundEnabled) { _, _ in
            RestTimerCoordinator.shared.rescheduleSystemNotifications()
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
            Button("前往系统设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
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
            String(settings.remindersEnabled),
            String(settings.reminderHour),
            String(settings.reminderMinute),
            String(settings.remindersOnPlannedDaysOnly),
            String(settings.skipReminderWhenCompleted)
        ].joined(separator: "#")
    }

    private func refreshAuthorizationState() async {
        authorizationState = await NotificationManager.authorizationState()
    }

    private func refreshDailyReminders() async {
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
    }

    private func sendTestNotification() {
        Task {
            let result = await NotificationManager.scheduleTestNotification(
                playsSound: settings.restSoundEnabled
            )
            notificationStatusMessage = switch result {
            case .scheduled: "测试提醒将在 3 秒后显示"
            case .permissionDenied: "系统通知权限未开启"
            case .failed: "测试提醒未能创建，请稍后重试"
            case .disabled, .noPlannedDays: nil
            }
            await refreshAuthorizationState()
        }
    }

    private func message(for result: NotificationScheduleResult) -> String? {
        switch result {
        case .scheduled:
            return "训练提醒已自动更新"
        case .disabled:
            return "训练提醒已关闭"
        case .noPlannedDays:
            return settings.remindersOnPlannedDaysOnly ? "当前没有可提醒的训练日" : nil
        case .permissionDenied:
            return "系统通知权限未开启"
        case .failed:
            return "提醒更新失败，请稍后重试"
        }
    }

    private var permissionLabel: String {
        switch authorizationState {
        case .allowed: "已允许"
        case .denied: "未允许"
        case .notDetermined: "尚未请求"
        case .unknown: "检查中"
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
        notificationStatusMessage?.contains("失败") == true ||
            notificationStatusMessage?.contains("未开启") == true
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
