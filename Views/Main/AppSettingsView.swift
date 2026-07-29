import SwiftUI
import UIKit

struct AppSettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var profile = LocalProfileStore.shared
    @State private var avatarImage: UIImage?

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ProfileEditorView()
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        profileAvatar

                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                profile.hasDisplayName
                                    ? profile.displayName
                                    : AppLocalization.string("设置昵称")
                            )
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    profile.hasDisplayName
                                        ? Theme.Color.textPrimary
                                        : Theme.Color.accent
                                )
                            Text(
                                profile.bio.isEmpty
                                    ? AppLocalization.string("头像、昵称与个性签名")
                                    : profile.bio
                            )
                                .font(.caption)
                                .foregroundStyle(Theme.Color.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .accessibilityHint("打开个人资料编辑页面")
            } header: {
                Text("个人资料")
            } footer: {
                Text("个人资料仅保存在你的设备上。")
            }

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
        .onAppear {
            avatarImage = ProfileAvatarStore.load()
        }
    }

    private var profileAvatar: some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Theme.Color.accentSoft)
                    Text("💪")
                        .font(.title2)
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.Color.hairline, lineWidth: avatarImage == nil ? 0 : 1)
        )
    }
}

private struct GeneralSettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    HStack {
                        Label("语言", systemImage: "globe")
                        Spacer()
                        Text(settings.languagePreference.languageName)
                            .foregroundStyle(.secondary)
                    }
                }

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

private struct LanguageSettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Picker("App 语言", selection: $settings.languagePreference) {
                    ForEach(AppLanguagePreference.allCases) { preference in
                        HStack {
                            Text(preference.languageName)
                            if preference == .system {
                                Spacer()
                                Text(systemLanguageDetail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(preference)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("App 语言")
            } footer: {
                Text("更改会立即应用到 App、训练提醒和桌面小组件，无需重新启动。自定义动作名称和个性签名会保持原样。")
            }
        }
        .navigationTitle("语言")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: settings.languagePreference)
    }

    private var systemLanguageDetail: String {
        AppLanguagePreference.system.resolvedIdentifier().hasPrefix("zh")
            ? "简体中文"
            : "English"
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
