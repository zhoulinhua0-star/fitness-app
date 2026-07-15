//
//  ProfileView.swift
//  FitnessApp
//
//  "Me" tab — Tiimo-style: avatar card with key stats at the top,
//  then the existing app settings below. All settings logic is unchanged.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @State private var settings = AppSettings.shared
    @State private var notificationStatusMessage: String?
    @State private var copiedEmail: String?
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse) private var sessions: [WorkoutSession]

    private var streak: Int { WorkoutHistoryManager.currentStreak(context: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    pageHeader
                    heroCard
                    settingsSection
                    aboutSection
                    feedbackSection
                }
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("邮箱已复制", isPresented: copiedEmailAlertBinding) {
                Button("好", role: .cancel) { }
            } message: {
                if let copiedEmail {
                    Text("\(copiedEmail) 已复制到剪贴板")
                }
            }
        }
    }

    // MARK: Page header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("我的")
                .font(.displayLarge)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("个人数据与设置")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: Hero card

    private var heroCard: some View {
        VStack(spacing: Theme.Spacing.l) {
            // Avatar
            ZStack {
                Circle().fill(Theme.Color.accentSoft)
                Text("💪")
                    .font(.system(size: 44))
            }
            .frame(width: 88, height: 88)

            Text(Brand.name)
                .font(.displayMedium)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(Brand.slogan)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)

            Divider().background(Theme.Color.hairline)

            // Stats row
            HStack {
                statBlock(value: "\(streak)", label: "连续打卡", unit: "天")
                Divider().frame(height: 44).background(Theme.Color.hairline)
                statBlock(value: "\(sessions.count)", label: "总训练次数", unit: "次")
                Divider().frame(height: 44).background(Theme.Color.hairline)
                statBlock(
                    value: "\(sessions.reduce(0) { $0 + $1.completedSetCount })",
                    label: "累计完成组",
                    unit: "组"
                )
            }
        }
        .tiimoCard(padding: Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func statBlock(value: String, label: String, unit: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.display(24, weight: .bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Settings section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "训练设置", systemImage: "gearshape.fill", tint: Theme.Color.tintBlue)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                // Rest duration
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("默认休息时长")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("休息结束后，若 App 在后台会推送提醒")
                            .font(.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Spacer()
                    Stepper("\(settings.defaultRestSeconds)秒", value: $settings.defaultRestSeconds, in: 30...300, step: 15)
                        .labelsHidden()
                        .foregroundStyle(Theme.Color.accent)
                }
                .padding(Theme.Spacing.l)

                Text("\(settings.defaultRestSeconds) 秒")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.s)

                Divider().background(Theme.Color.hairline).padding(.horizontal, Theme.Spacing.l)

                // Reminders
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Toggle(isOn: $settings.remindersEnabled) {
                        Text("每日训练提醒")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Color.textPrimary)
                    }
                    .tint(Theme.Color.accent)

                    if settings.remindersEnabled {
                        DatePicker("提醒时间", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                            .foregroundStyle(Theme.Color.textPrimary)
                    }

                    Button("更新提醒设置") {
                        Task {
                            await NotificationManager.scheduleDailyReminder(settings: settings)
                            notificationStatusMessage = settings.remindersEnabled ? "提醒已更新 ✓" : "提醒已关闭"
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)

                    if let msg = notificationStatusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Color.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: About section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "关于", systemImage: "info.circle.fill", tint: Theme.Color.surfaceMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                aboutRow(label: "版本", value: "1.1.0")
                Divider().background(Theme.Color.hairline).padding(.horizontal, Theme.Spacing.l)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("🔒 完全本地存储")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("所有数据保存在你的设备上，不上传任何云端。")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.l)
            }
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Color.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.l)
    }

    // MARK: Feedback section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "建议与反馈", systemImage: "envelope.fill", tint: Theme.Color.tintMint)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("有建议或发现问题？欢迎直接联系我。")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("Suggestions and feedback are always welcome.")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.l)

                Divider().background(Theme.Color.hairline).padding(.horizontal, Theme.Spacing.l)

                feedbackEmailRow(
                    audience: "中国用户",
                    address: "lincolnzlh@163.com",
                    language: .chinese
                )

                Divider().background(Theme.Color.hairline).padding(.horizontal, Theme.Spacing.l)

                feedbackEmailRow(
                    audience: "International users",
                    address: "zhoulinhua0@gmail.com",
                    language: .english
                )
            }
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.Color.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private enum FeedbackLanguage {
        case chinese, english
    }

    private func feedbackEmailRow(
        audience: String,
        address: String,
        language: FeedbackLanguage
    ) -> some View {
        Button {
            openFeedbackEmail(address: address, language: language)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "envelope")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(audience)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                Spacer(minLength: Theme.Spacing.s)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("给开发者发送邮件，\(address)")
        .accessibilityHint("打开系统邮件 App")
        .contextMenu {
            Button {
                copyEmail(address)
            } label: {
                Label("复制邮箱", systemImage: "doc.on.doc")
            }
        }
    }

    private func openFeedbackEmail(address: String, language: FeedbackLanguage) {
        guard let url = feedbackEmailURL(address: address, language: language) else {
            copyEmail(address)
            return
        }

        openURL(url) { accepted in
            guard !accepted else { return }
            Task { @MainActor in
                copyEmail(address)
            }
        }
    }

    private func feedbackEmailURL(address: String, language: FeedbackLanguage) -> URL? {
        let subject: String
        let body: String

        switch language {
        case .chinese:
            subject = "RepDay 使用建议"
            body = "你好，\n\n我想反馈：\n\n\nApp 版本：1.1.0"
        case .english:
            subject = "RepDay Feedback"
            body = "Hi Lincoln,\n\nI’d like to share the following feedback:\n\n\nApp version: 1.1.0"
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

    private func copyEmail(_ address: String) {
        UIPasteboard.general.string = address
        copiedEmail = address
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var copiedEmailAlertBinding: Binding<Bool> {
        Binding(
            get: { copiedEmail != nil },
            set: { if !$0 { copiedEmail = nil } }
        )
    }

    // MARK: Reminder time binding

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = settings.reminderHour
                c.minute = settings.reminderMinute
                return Calendar.current.date(from: c) ?? .now
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.reminderHour = c.hour ?? 19
                settings.reminderMinute = c.minute ?? 0
            }
        )
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [WorkoutSession.self, WorkoutDay.self], inMemory: true)
}
