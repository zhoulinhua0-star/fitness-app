import AVFoundation
import PhotosUI
import SwiftUI

struct ProfileEditorView: View {
    @State private var profile = LocalProfileStore.shared
    @State private var draftDisplayName = LocalProfileStore.shared.displayName
    @State private var draftBio = LocalProfileStore.shared.bio
    @State private var avatarImage = ProfileAvatarStore.load()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isAvatarMenuPresented = false
    @State private var isCameraPresented = false
    @State private var isProcessingAvatar = false
    @State private var avatarFrame: CGRect = .zero
    @State private var avatarAlert: ProfileAvatarAlert?
    @FocusState private var focusedField: Field?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private enum Field {
        case displayName
        case bio
    }

    var body: some View {
        ZStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        avatarButton
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("点击头像可从照片图库选择、拍照或删除当前头像。")
                }

                Section {
                    profileField(
                        title: "昵称",
                        count: draftDisplayName.count,
                        limit: LocalProfileStore.displayNameLimit
                    ) {
                        TextField("设置昵称", text: $draftDisplayName)
                            .focused($focusedField, equals: .displayName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .bio }
                    }

                    profileField(
                        title: "个性签名",
                        count: draftBio.count,
                        limit: LocalProfileStore.bioLimit
                    ) {
                        TextField(
                            "例如：今天也要组组爆拉！",
                            text: $draftBio,
                            axis: .vertical
                        )
                        .focused($focusedField, equals: .bio)
                        .lineLimit(2...3)
                        .submitLabel(.done)
                    }
                } header: {
                    Text("个人信息")
                } footer: {
                    Text("昵称、个性签名和头像仅保存在你的设备上，不会上传。")
                }
            }
            .blur(radius: isAvatarMenuPresented ? 1.5 : 0)
            .allowsHitTesting(!isAvatarMenuPresented)

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
        .coordinateSpace(name: "profileEditorRoot")
        .onPreferenceChange(ProfileEditorAvatarFramePreferenceKey.self) {
            avatarFrame = $0
        }
        .navigationTitle("编辑个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    saveProfile()
                    dismiss()
                }
            }
        }
        .onDisappear {
            saveProfile()
        }
        .onChange(of: draftDisplayName) { _, newValue in
            draftDisplayName = LocalProfileStore.limited(
                newValue,
                to: LocalProfileStore.displayNameLimit
            )
        }
        .onChange(of: draftBio) { _, newValue in
            draftBio = LocalProfileStore.limited(
                newValue,
                to: LocalProfileStore.bioLimit
            )
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

    private func profileField<Content: View>(
        title: String,
        count: Int,
        limit: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(AppLocalization.string(title))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
                Spacer()
                Text("\(count)/\(limit)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            content()
                .font(.body)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func saveProfile() {
        profile.update(displayName: draftDisplayName, bio: draftBio)
        draftDisplayName = profile.displayName
        draftBio = profile.bio
    }

    // MARK: Avatar

    private var avatarButton: some View {
        Button {
            guard !isProcessingAvatar else { return }
            focusedField = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            setAvatarMenuPresented(!isAvatarMenuPresented)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                avatarImageView(size: 112)

                ZStack {
                    Circle().fill(Theme.Color.surface)
                    Image(systemName: "camera.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.Color.textPrimary)
                }
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Theme.Color.hairline, lineWidth: 1)
                )
                .shadow(color: Theme.Shadow.color, radius: 5, y: 2)

                if isProcessingAvatar {
                    Circle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 112, height: 112)
                    ProgressView()
                        .tint(.white)
                        .frame(width: 112, height: 112)
                }
            }
            .contentShape(Circle())
            .scaleEffect(
                isAvatarMenuPresented && !accessibilityReduceMotion ? 1.045 : 1
            )
        }
        .buttonStyle(ProfileEditorAvatarPressStyle())
        .disabled(isProcessingAvatar)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ProfileEditorAvatarFramePreferenceKey.self,
                    value: proxy.frame(in: .named("profileEditorRoot"))
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

    private func avatarImageView(size: CGFloat) -> some View {
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
                        .font(.system(size: 52))
                }
                .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Theme.Color.surface, lineWidth: avatarImage == nil ? 0 : 2)
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

            Text(AppLocalization.string(title))
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

    private func avatarAlertView(for alert: ProfileAvatarAlert) -> Alert {
        switch alert {
        case .cameraPermissionDenied:
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .default(Text("前往设置")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
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
}

private enum ProfileAvatarAlert: String, Identifiable {
    case photoLoadFailed
    case saveFailed
    case cameraUnavailable
    case cameraPermissionDenied

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photoLoadFailed: AppLocalization.string("无法读取照片")
        case .saveFailed: AppLocalization.string("无法保存头像")
        case .cameraUnavailable: AppLocalization.string("相机不可用")
        case .cameraPermissionDenied: AppLocalization.string("需要相机权限")
        }
    }

    var message: String {
        switch self {
        case .photoLoadFailed:
            AppLocalization.string("请选择另一张照片后重试。")
        case .saveFailed:
            AppLocalization.string("头像未能保存到本机，请稍后重试。")
        case .cameraUnavailable:
            AppLocalization.string("当前设备无法使用相机，你仍然可以从照片图库选择头像。")
        case .cameraPermissionDenied:
            AppLocalization.string("请在系统设置中允许 RepDay 使用相机，然后再次选择“拍照”。")
        }
    }
}

private struct ProfileEditorAvatarFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct ProfileEditorAvatarPressStyle: ButtonStyle {
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

#Preview {
    NavigationStack {
        ProfileEditorView()
    }
}
