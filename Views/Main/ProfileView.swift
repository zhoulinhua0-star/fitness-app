//
//  ProfileView.swift
//  FitnessApp
//
//  "Me" tab — local profile, training progress, and app settings.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @State private var copiedEmail: String?
    @State private var avatarImage: UIImage?
    @State private var profile = LocalProfileStore.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse) private var sessions: [WorkoutSession]

    private var streak: Int { WorkoutHistoryManager.currentStreak(context: modelContext) }
    private var trainingProgress: TrainingProgress {
        let calendar = Calendar.current
        let days = Set(
            sessions
                .filter { $0.completedSetCount > 0 || $0.completedCardioCount > 0 }
                .map { calendar.startOfDay(for: $0.sessionDate) }
        )
        return TrainingProgress(effectiveTrainingDays: days.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    pageHeader
                    heroCard
                    settingsSection
                    aboutSection
                    feedbackSection
                    brandFooter
                }
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .alert("邮箱已复制", isPresented: copiedEmailAlertBinding) {
                Button("好", role: .cancel) { }
            } message: {
                if let copiedEmail {
                    Text("\(copiedEmail) 已复制到剪贴板")
                }
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                avatarImage = ProfileAvatarStore.load()
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
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: Hero card

    private var heroCard: some View {
        VStack(spacing: Theme.Spacing.l) {
            profileIdentity

            Divider().background(Theme.Color.hairline)

            trainingLevelProgress

            Divider().background(Theme.Color.hairline)

            profileStats
        }
        .tiimoCard(padding: Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var profileIdentity: some View {
        NavigationLink(destination: ProfileEditorView()) {
            VStack(spacing: Theme.Spacing.m) {
                ZStack(alignment: .bottomTrailing) {
                    profileAvatar(size: 88)

                    ZStack {
                        Circle().fill(Theme.Color.surface)
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.Color.textPrimary)
                    }
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Theme.Color.hairline, lineWidth: 1)
                    )
                    .shadow(color: Theme.Shadow.color, radius: 5, y: 2)
                }

                profileNameAndLevel

                Text(profileSubtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开个人资料编辑页面")
    }

    private func profileAvatar(size: CGFloat) -> some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Theme.Color.accentSoft)
                    Text("💪")
                        .font(.system(size: 44))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.Color.surface, lineWidth: avatarImage == nil ? 0 : 2)
        )
    }

    @ViewBuilder
    private var profileNameAndLevel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Theme.Spacing.s) {
                profileName
                levelBadge
            }
        } else {
            HStack(spacing: Theme.Spacing.s) {
                profileName
                levelBadge
            }
        }
    }

    private var profileName: some View {
        Text(
            profile.hasDisplayName
                ? profile.displayName
                : AppLocalization.string("设置昵称")
        )
            .font(.displayMedium)
            .foregroundStyle(
                profile.hasDisplayName
                    ? Theme.Color.textPrimary
                    : Theme.Color.accent
            )
            .multilineTextAlignment(.center)
    }

    private var levelBadge: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "shield.fill")
            if let level = trainingProgress.currentLevel {
                Text("Lv.\(level.number) \(level.title)")
            } else {
                Text("待启程")
            }
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Theme.Color.accent)
        .padding(.horizontal, Theme.Spacing.s)
        .frame(minHeight: 28)
        .background(Theme.Color.accentSoft, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var profileSubtitle: String {
        if !profile.bio.isEmpty {
            return profile.bio
        }
        if trainingProgress.effectiveTrainingDays == 0 {
            return AppLocalization.string("从今天开始，记录第一次训练")
        }
        return AppLocalization.format(
            "已记录 %lld 个有效训练日",
            trainingProgress.effectiveTrainingDays
        )
    }

    private var trainingLevelProgress: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "shield.checkered")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 32, height: 32)
                    .background(Theme.Color.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(trainingLevelTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(trainingLevelDetail)
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }

            ProgressView(value: trainingProgress.progressFraction)
                .tint(Theme.Color.accent)
                .accessibilityLabel("训练等级进度")
                .accessibilityValue(trainingLevelDetail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trainingLevelTitle: String {
        guard let level = trainingProgress.currentLevel else {
            return AppLocalization.string("准备启程")
        }
        return "Lv.\(level.number) · \(level.title)"
    }

    private var trainingLevelDetail: String {
        let dayCount = trainingProgress.effectiveTrainingDays
        guard let nextLevel = trainingProgress.nextLevel else {
            return AppLocalization.format(
                "已完成 %lld 个有效训练日 · 当前最高等级",
                dayCount
            )
        }
        if trainingProgress.currentLevel == nil {
            return AppLocalization.format(
                "完成第一次有效训练即可达到 Lv.%lld",
                nextLevel.number
            )
        }
        return AppLocalization.format(
            "已完成 %lld 个有效训练日 · 再训练 %lld 个训练日升级",
            dayCount,
            trainingProgress.daysToNextLevel
        )
    }

    @ViewBuilder
    private var profileStats: some View {
        let blocks = [
            (value: "\(streak)", label: "连续打卡", unit: "天"),
            (value: "\(sessions.count)", label: "总训练次数", unit: "次"),
            (
                value: "\(sessions.reduce(0) { $0 + $1.completedSetCount })",
                label: "累计完成组",
                unit: "组"
            )
        ]

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Theme.Spacing.m) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    statBlock(value: block.value, label: block.label, unit: block.unit)
                    if index < blocks.count - 1 {
                        Divider().background(Theme.Color.hairline)
                    }
                }
            }
        } else {
            HStack {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    statBlock(value: block.value, label: block.label, unit: block.unit)
                    if index < blocks.count - 1 {
                        Divider().frame(height: 44).background(Theme.Color.hairline)
                    }
                }
            }
        }
    }

    private func statBlock(value: String, label: String, unit: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.displayMetricSmall)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(AppLocalization.string(unit))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Text(AppLocalization.string(label))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Settings section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "设置", systemImage: "gearshape.fill", tint: Theme.Color.tintBlue)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(destination: AppSettingsView()) {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Color.accent)
                        .frame(width: 36, height: 36)
                        .background(Theme.Color.accentSoft, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("设置")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("个人资料、通用、训练与通知")
                            .font(.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                aboutRow(label: "版本", value: appVersion)
                Divider().background(Theme.Color.hairline).padding(.horizontal, Theme.Spacing.l)
                NavigationLink(destination: PrivacyPolicyView()) {
                    HStack {
                        Text("隐私政策 / Privacy Policy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Color.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    .padding(Theme.Spacing.l)
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Color.hairline).padding(.horizontal, Theme.Spacing.l)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("🔒 完全本地存储")
                        .font(.subheadline.weight(.semibold))
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
            Text(AppLocalization.string(label))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
            Text(value)
                .font(.subheadline)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppLocalization.string(audience))
                        .font(.subheadline.weight(.semibold))
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
            body = "你好，\n\n我想反馈：\n\n\nApp 版本：\(appVersion)"
        case .english:
            subject = "RepDay Feedback"
            body = "Hi Lincoln,\n\nI’d like to share the following feedback:\n\n\nApp version: \(appVersion)"
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

    private var brandFooter: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(Brand.name)
                .font(.caption.weight(.semibold))
            Text(Brand.slogan)
                .font(.caption2)
        }
        .foregroundStyle(Theme.Color.textSecondary)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("Effective date: July 16, 2026")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)

                policySection(
                    title: "Summary",
                    body: "RepDay does not require an account. We do not collect, transmit, sell, or share your personal data, and we do not use advertising, analytics, or tracking SDKs."
                )
                policySection(
                    title: "Workout data",
                    body: "Your plans, exercises, workout logs, and history are stored locally on your device. A small amount of workout information is shared locally with the RepDay widget through Apple’s App Groups system. It is not sent to us or any third party."
                )
                policySection(
                    title: "Profile data",
                    body: "Your optional nickname, bio, and profile photo are stored locally on your device. They are not uploaded or shared with us or any third party."
                )
                policySection(
                    title: "Calendar access (optional)",
                    body: "If you choose Sync to Calendar, RepDay uses Apple’s EventKit framework to create and update a dedicated workout calendar on your device. Calendar information is not transmitted to us or any third party. You can revoke calendar access in the Settings app."
                )
                policySection(
                    title: "Notifications (optional)",
                    body: "If you enable reminders or a rest timer, RepDay schedules local notifications on your device. We do not use a notification server. You can revoke notification permission in the Settings app."
                )
                policySection(
                    title: "Feedback",
                    body: "When you choose to contact us, RepDay opens your email app with a draft. Nothing is sent unless you choose to send the email."
                )
                policySection(
                    title: "Data retention and deletion",
                    body: "Because we do not collect your data, we do not retain it on our systems. Deleting RepDay removes data stored by the app. Calendar events created at your request remain under your control in the Calendar app."
                )
                policySection(
                    title: "Children’s privacy",
                    body: "RepDay is not directed at children under 13 and does not knowingly collect personal information from anyone."
                )
                policySection(
                    title: "Contact",
                    body: "Questions about this policy: zhoulinhua0@gmail.com"
                )
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(AppLocalization.string(title))
                .font(.headline)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(AppLocalization.string(body))
                .font(.body)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [WorkoutSession.self, WorkoutDay.self, Exercise.self, SetLog.self, CardioLog.self], inMemory: true)
}
