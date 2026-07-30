import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedNames: Set<String>
    let onSelect: (ExerciseDefinition) -> Void

    @State private var searchText = ""
    @State private var selectedActivityType: ExerciseActivityType?
    @State private var selectedBodyPart: ExerciseBodyPart?

    private var filteredDefinitions: [ExerciseDefinition] {
        ExerciseLibrary.definitions.filter { definition in
            let matchesSearch = searchText.isEmpty ||
                definition.name.localizedCaseInsensitiveContains(searchText) ||
                definition.localizedName.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedActivityType.map { definition.activityType == $0 } ?? true
            let matchesBodyPart = selectedBodyPart.map { definition.bodyPart == $0 } ?? true
            return matchesSearch && matchesType && matchesBodyPart
        }
    }

    var body: some View {
        NavigationStack {
            List {
                filterSection

                Section {
                    if filteredDefinitions.isEmpty {
                        ContentUnavailableView(
                            "没有找到动作",
                            systemImage: "magnifyingglass",
                            description: Text("尝试更换搜索词或清除筛选条件")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredDefinitions) { definition in
                            exerciseRow(definition)
                        }
                    }
                } header: {
                    Text("动作 · \(filteredDefinitions.count)")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("动作库")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索动作")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedActivityType) { _, newValue in
                if newValue == .cardio {
                    selectedBodyPart = nil
                }
            }
        }
        .presentationBackground(Theme.Color.background)
    }

    private var filterSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.s) {
                filterMenu(
                    title: selectedActivityType?.title ?? "全部类型",
                    systemImage: selectedActivityType?.systemImage ?? "slider.horizontal.3"
                ) {
                    Button("全部类型") { selectedActivityType = nil }
                    ForEach(ExerciseActivityType.allCases) { type in
                        Button {
                            selectedActivityType = type
                        } label: {
                            Label(type.title, systemImage: type.systemImage)
                        }
                    }
                }

                filterMenu(
                    title: selectedBodyPart?.title ?? "全部部位",
                    systemImage: selectedBodyPart?.systemImage ?? "figure.mixed.cardio"
                ) {
                    Button("全部部位") { selectedBodyPart = nil }
                    ForEach(ExerciseBodyPart.allCases) { bodyPart in
                        Button {
                            selectedBodyPart = bodyPart
                        } label: {
                            Label(bodyPart.title, systemImage: bodyPart.systemImage)
                        }
                    }
                }
                .disabled(selectedActivityType == .cardio)
                .opacity(selectedActivityType == .cardio ? 0.45 : 1)
            }

            if selectedActivityType != nil || selectedBodyPart != nil {
                Button {
                    selectedActivityType = nil
                    selectedBodyPart = nil
                } label: {
                    Label("清除筛选", systemImage: "xmark.circle")
                        .frame(minHeight: 44)
                }
            }
        } footer: {
            if selectedActivityType == .cardio {
                Text("有氧动作按时长记录，因此不需要身体部位筛选")
            }
        }
        .listRowBackground(Theme.Color.surface)
    }

    private func exerciseRow(_ definition: ExerciseDefinition) -> some View {
        let isSelected = selectedNames.contains(definition.name)

        return Button {
            guard !isSelected else { return }
            onSelect(definition)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                ExerciseIconTile(definition: definition, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(definition.localizedName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(definition.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                Spacer(minLength: Theme.Spacing.s)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.Color.success : Theme.Color.accent)
                    .frame(width: 44, height: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
        .accessibilityLabel(
            isSelected
                ? AppLocalization.format("%@，已添加", definition.localizedName)
                : AppLocalization.format("添加%@", definition.localizedName)
        )
        .listRowBackground(Theme.Color.surface)
    }

    private func filterMenu<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: systemImage)
                Text(AppLocalization.string(title))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Color.textPrimary)
            .padding(.horizontal, Theme.Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.Color.surfaceMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct DurationSettingControl: View {
    let title: String
    @Binding var seconds: Int
    @Environment(\.locale) private var locale
    @State private var showingDurationPicker = false
    @State private var draftMinutes = 20

    private let minuteRange = 1...180

    private var currentMinutes: Int {
        min(max(seconds / 60, minuteRange.lowerBound), minuteRange.upperBound)
    }

    private var stepValues: [Int] {
        var values = [minuteRange.lowerBound]
        values.append(contentsOf: stride(from: 5, through: minuteRange.upperBound, by: 5))
        if !values.contains(currentMinutes) {
            values.append(currentMinutes)
            values.sort()
        }
        return values
    }

    private var stepIndexBinding: Binding<Int> {
        Binding(
            get: { stepValues.firstIndex(of: currentMinutes) ?? 0 },
            set: { newIndex in
                let values = stepValues
                guard values.indices.contains(newIndex) else { return }
                seconds = values[newIndex] * 60
            }
        )
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                draftMinutes = currentMinutes
                showingDurationPicker = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        AppLocalization.string(
                            title,
                            languageIdentifier: locale.identifier
                        )
                    )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.Color.textSecondary)

                    HStack(spacing: Theme.Spacing.xs) {
                        Text(ExerciseFormatting.shortDuration(seconds))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.Color.accent)
                            .monospacedDigit()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                AppLocalization.string(
                    title,
                    languageIdentifier: locale.identifier
                )
            )
            .accessibilityValue(ExerciseFormatting.shortDuration(seconds))
            .accessibilityHint(
                AppLocalization.string(
                    "轻点选择任意分钟",
                    languageIdentifier: locale.identifier
                )
            )

            Stepper(
                value: stepIndexBinding,
                in: 0...(stepValues.count - 1)
            ) {
                EmptyView()
            }
            .labelsHidden()
            .accessibilityLabel(
                AppLocalization.string(
                    "快速调整目标时长",
                    languageIdentifier: locale.identifier
                )
            )
            .accessibilityValue(ExerciseFormatting.shortDuration(seconds))
        }
        .frame(minHeight: 44)
        .sheet(isPresented: $showingDurationPicker) {
            DurationSelectionSheet(
                selectedMinutes: $draftMinutes,
                minuteRange: minuteRange
            ) {
                seconds = draftMinutes * 60
            }
        }
    }
}

private struct DurationSelectionSheet: View {
    @Binding var selectedMinutes: Int
    let minuteRange: ClosedRange<Int>
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let presets = [10, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 64), spacing: Theme.Spacing.s)],
                        spacing: Theme.Spacing.s
                    ) {
                        ForEach(presets, id: \.self) { minutes in
                            Button {
                                selectedMinutes = minutes
                            } label: {
                                Text(localizedMinutes(minutes))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(
                                        selectedMinutes == minutes
                                            ? Color.white
                                            : Theme.Color.textPrimary
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        selectedMinutes == minutes
                                            ? Theme.Color.accent
                                            : Theme.Color.surfaceMuted,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(
                                selectedMinutes == minutes ? .isSelected : []
                            )
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                } header: {
                    Text(
                        AppLocalization.string(
                            "常用时长",
                            languageIdentifier: locale.identifier
                        )
                    )
                }

                Section {
                    Picker(
                        AppLocalization.string(
                            "精确时长",
                            languageIdentifier: locale.identifier
                        ),
                        selection: $selectedMinutes
                    ) {
                        ForEach(minuteRange, id: \.self) { minutes in
                            Text(localizedMinutes(minutes))
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                } header: {
                    Text(
                        AppLocalization.string(
                            "精确时长",
                            languageIdentifier: locale.identifier
                        )
                    )
                } footer: {
                    Text(
                        AppLocalization.string(
                            "可选择 1 至 180 分钟",
                            languageIdentifier: locale.identifier
                        )
                    )
                }
            }
            .navigationTitle(
                AppLocalization.string(
                    "选择目标时长",
                    languageIdentifier: locale.identifier
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        AppLocalization.string(
                            "取消",
                            languageIdentifier: locale.identifier
                        )
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        AppLocalization.string(
                            "完成",
                            languageIdentifier: locale.identifier
                        )
                    ) {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func localizedMinutes(_ minutes: Int) -> String {
        AppLocalization.format(
            "%lld 分钟",
            languageIdentifier: locale.identifier,
            Int64(minutes)
        )
    }
}
