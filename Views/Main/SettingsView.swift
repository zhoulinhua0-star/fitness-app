//
//  SettingsView.swift
//  FitnessApp
//

import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var notificationStatusMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "默认休息时长: \(settings.defaultRestSeconds) 秒",
                        value: $settings.defaultRestSeconds,
                        in: 30...300,
                        step: 15
                    )
                    
                    Text("休息结束时，若 App 在后台会推送提醒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("训练")
                }
                
                Section("提醒") {
                    Toggle("每日训练提醒", isOn: $settings.remindersEnabled)
                    
                    if settings.remindersEnabled {
                        DatePicker(
                            "提醒时间",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    
                    Button("更新提醒设置") {
                        Task {
                            await NotificationManager.scheduleDailyReminder(settings: settings)
                            notificationStatusMessage = settings.remindersEnabled
                                ? "提醒已更新"
                                : "提醒已关闭"
                        }
                    }
                    
                    if let notificationStatusMessage {
                        Text(notificationStatusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("小组件") {
                    Text("在桌面添加「FitnessApp」小组件，可查看今日训练进度。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("当前进度")
                        Spacer()
                        Text("\(WidgetDataStore.completedSets)/\(WidgetDataStore.totalSets) 组")
                            .foregroundColor(.accentColor)
                    }
                }
                
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.1.0")
                            .foregroundColor(.secondary)
                    }
                    Text("100% 本地存储，数据保存在你的设备上。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
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
}

#Preview {
    SettingsView()
}
