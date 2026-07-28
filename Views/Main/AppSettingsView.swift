import SwiftUI

struct AppSettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    GeneralSettingsView()
                } label: {
                    Label("通用", systemImage: "gearshape")
                }
            } footer: {
                Text("调整 RepDay 的显示方式。")
            }

            Section("训练") {
                Stepper(
                    "默认休息时长：\(settings.defaultRestSeconds) 秒",
                    value: $settings.defaultRestSeconds,
                    in: 30...300,
                    step: 15
                )
                Text("每个动作仍可以在训练中单独调整。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("通知与提醒", systemImage: "bell.badge")
                }
            } footer: {
                Text("管理休息计时、每日训练提醒与系统通知权限。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GeneralSettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TextSizeSettingsView()
                } label: {
                    HStack {
                        Label("字体大小", systemImage: "textformat.size")
                        Spacer()
                        Text(settings.textSizePreference.title)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("文字会继续响应 iPhone 的系统文字大小设置。")
            }
        }
        .navigationTitle("通用")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TextSizeSettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("预览") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("卧推")
                        .font(.headline)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("3 组 × 10 次")
                        .font(.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("训练时把手机放远一些，也能快速看清动作和次数。")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section {
                Picker("字体大小", selection: $settings.textSizePreference) {
                    ForEach(AppTextSizePreference.allCases) { preference in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preference.title)
                            Text(preference.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(preference)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("“标准”是推荐的默认显示；“紧凑”会再缩小一级；“大字”跟随系统文字大小。设置会自动保存。")
            }
        }
        .navigationTitle("字体大小")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
}
