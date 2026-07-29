//
//  ProfileView.swift
//  FitnessApp
//
//  "Me" tab — Tiimo-style: avatar card with key stats at the top,
//  then the existing app settings below. All settings logic is unchanged.
//

import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct ProfileView: View {
    @State private var copiedEmail: String?
    @State private var avatarImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isAvatarMenuPresented = false
    @State private var isCameraPresented = false
    @State private var isProcessingAvatar = false
    @State private var avatarFrame: CGRect = .zero
    @State private var avatarAlert: AvatarAlert?
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse) private var sessions: [WorkoutSession]

    private var streak: Int { WorkoutHistoryManager.currentStreak(context: modelContext) }

    var body: some View {
        NavigationStack {
            ZStack {
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
                .blur(radius: isAvatarMenuPresented ? 1.5 : 0)
                .allowsHitTesting(!isAvatarMenuPresented)
                .alert("邮箱已复制", isPresented: copiedEmailAlertBinding) {
                    Button("好", role: .cancel) { }
                } message: {
                    if let copiedEmail {
                        Text("\(copiedEmail) 已复制到剪贴板")
                    }
                }

                if isAvatarMenuPresented {
                    avatarMenuOverlay
                        .transition(
                            accessibilityReduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.94, anchor: .top))
                        )
                        .zIndex(10)
                }
            }
            .coordinateSpace(name: "profileRoot")
            .onPreferenceChange(AvatarFramePreferenceKey.self) { avatarFrame = $0 }
            .background(Theme.Color.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                avatarImage = ProfileAvatarStore.load()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                setAvatarMenuPresented(false)
                loadPhoto(from: newItem)
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                ProfileAvatarCameraPicker { image in
                    saveAvatar(image)
                }
                .ignoresSafeArea()
            }
            .alert(item: $avatarAlert) { alert in
                avatarAlertView(for: alert)
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
            avatarButton

            Text(Brand.name)
                .font(.displayMedium)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(Brand.slogan)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Color.textSecondary)

            Divider().background(Theme.Color.hairline)

            // Stats row
            profileStats
        }
        .tiimoCard(padding: Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: Avatar

    private var avatarButton: some View {
        Button {
            guard !isProcessingAvatar else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            setAvatarMenuPresented(!isAvatarMenuPresented)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        ZStack {
                            Circle().fill(Theme.Color.accentSoft)
                            Text("💪")
                                .font(.system(size: 44))
                        }
                        .transition(.opacity)
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.Color.surface, lineWidth: avatarImage == nil ? 0 : 2)
                )

                ZStack {
                    Circle().fill(Theme.Color.surface)
                    Image(systemName: "camera.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.Color.textPrimary)
                }
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Theme.Color.hairline, lineWidth: 1)
                )
                .shadow(color: Theme.Shadow.color, radius: 5, y: 2)

                if isProcessingAvatar {
                    Circle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 88, height: 88)
                    ProgressView()
                        .tint(.white)
                        .frame(width: 88, height: 88)
                }
            }
            .contentShape(Circle())
            .scaleEffect(
                isAvatarMenuPresented && !accessibilityReduceMotion ? 1.045 : 1
            )
        }
        .buttonStyle(ProfileAvatarPressStyle())
        .disabled(isProcessingAvatar)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AvatarFramePreferenceKey.self,
                    value: proxy.frame(in: .named("profileRoot"))
                )
            }
        }
        .accessibilityLabel(avatarImage == nil ? "设置头像" : "更换头像")
        .accessibilityHint("打开照片图库和相机选项")
        .animation(
            accessibilityReduceMotion
                ? nil
                : .spring(response: 0.28, dampingFraction: 0.82),
            value: isAvatarMenuPresented
        )
    }

    private var avatarMenuOverlay: some View {
        GeometryReader { proxy in
            let menuWidth = min(276, proxy.size.width - Theme.Spacing.xl * 2)
            let rowCount: CGFloat = avatarImage == nil ? 2 : 3
            let menuHeight = rowCount * 56 + 16
            let halfWidth = menuWidth / 2
            let halfHeight = menuHeight / 2
            let menuX = min(
                max(avatarFrame.midX, halfWidth + Theme.Spacing.xl),
                proxy.size.width - halfWidth - Theme.Spacing.xl
            )
            let preferredY = avatarFrame.maxY + Theme.Spacing.l + halfHeight
            let menuY = min(
                preferredY,
                proxy.size.height - halfHeight - Theme.Spacing.xl
            )

            ZStack {
                Color.black
                    .opacity(colorScheme == .dark ? 0.42 : 0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        setAvatarMenuPresented(false)
                    }
                    .accessibilityLabel("关闭头像菜单")
                    .accessibilityAddTraits(.isButton)

                avatarSourceMenu
                    .frame(width: menuWidth)
                    .position(x: menuX, y: menuY)
            }
        }
    }

    private var avatarSourceMenu: some View {
        VStack(spacing: 0) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                avatarMenuRow(title: "照片图库", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.plain)

            avatarMenuDivider

            Button {
                startCamera()
            } label: {
                avatarMenuRow(title: "拍照", systemImage: "camera")
            }
            .buttonStyle(.plain)

            if avatarImage != nil {
                avatarMenuDivider

                Button(role: .destructive) {
                    deleteAvatar()
                } label: {
                    avatarMenuRow(
                        title: "删除头像",
                        systemImage: "trash",
                        tint: Theme.Color.accent
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Theme.Color.hairline,
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var avatarMenuDivider: some View {
        Divider()
            .background(Theme.Color.hairline)
            .padding(.leading, 56)
    }

    private func avatarMenuRow(
        title: String,
        systemImage: String,
        tint: Color = Theme.Color.textPrimary
    ) -> some View {
        HStack(spacing: Theme.Spacing.l) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func setAvatarMenuPresented(_ isPresented: Bool) {
        if accessibilityReduceMotion {
            isAvatarMenuPresented = isPresented
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isAvatarMenuPresented = isPresented
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) {
        isProcessingAvatar = true
        Task {
            defer {
                selectedPhotoItem = nil
                isProcessingAvatar = false
            }

            do {
                guard
                    let data = try await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                else {
                    avatarAlert = .photoLoadFailed
                    return
                }
                persistAvatar(image)
            } catch {
                avatarAlert = .photoLoadFailed
            }
        }
    }

    private func saveAvatar(_ image: UIImage) {
        isProcessingAvatar = true
        persistAvatar(image)
        isProcessingAvatar = false
    }

    private func persistAvatar(_ image: UIImage) {
        do {
            let storedImage = try ProfileAvatarStore.save(image)
            if accessibilityReduceMotion {
                avatarImage = storedImage
            } else {
                withAnimation(.easeOut(duration: 0.22)) {
                    avatarImage = storedImage
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            avatarAlert = .saveFailed
        }
    }

    private func deleteAvatar() {
        setAvatarMenuPresented(false)
        do {
            try ProfileAvatarStore.delete()
            if accessibilityReduceMotion {
                avatarImage = nil
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    avatarImage = nil
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            avatarAlert = .saveFailed
        }
    }

    private func startCamera() {
        setAvatarMenuPresented(false)

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            avatarAlert = .cameraUnavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraPresented = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    isCameraPresented = true
                } else {
                    avatarAlert = .cameraPermissionDenied
                }
            }
        case .denied, .restricted:
            avatarAlert = .cameraPermissionDenied
        @unknown default:
            avatarAlert = .cameraUnavailable
        }
    }

    private func avatarAlertView(for alert: AvatarAlert) -> Alert {
        switch alert {
        case .cameraPermissionDenied:
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .default(Text("前往设置")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        default:
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("好"))
            )
        }
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
                Text(unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Text(label)
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
                        Text("通用、训练与通知")
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
            Text(label)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(audience)
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

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

}

private enum AvatarAlert: String, Identifiable {
    case photoLoadFailed
    case saveFailed
    case cameraUnavailable
    case cameraPermissionDenied

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photoLoadFailed: "无法读取照片"
        case .saveFailed: "无法保存头像"
        case .cameraUnavailable: "相机不可用"
        case .cameraPermissionDenied: "需要相机权限"
        }
    }

    var message: String {
        switch self {
        case .photoLoadFailed:
            "请选择另一张照片后重试。"
        case .saveFailed:
            "头像未能保存到本机，请稍后重试。"
        case .cameraUnavailable:
            "当前设备无法使用相机，你仍然可以从照片图库选择头像。"
        case .cameraPermissionDenied:
            "请在系统设置中允许 RepDay 使用相机，然后再次选择“拍照”。"
        }
    }
}

private struct AvatarFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct ProfileAvatarPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !accessibilityReduceMotion ? 0.96 : 1
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(
                accessibilityReduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
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
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [WorkoutSession.self, WorkoutDay.self, Exercise.self, SetLog.self, CardioLog.self], inMemory: true)
}
