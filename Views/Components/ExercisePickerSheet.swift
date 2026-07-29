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
                definition.name.localizedCaseInsensitiveContains(searchText)
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
                    Text(definition.name)
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
        .accessibilityLabel(isSelected ? "\(definition.name)，已添加" : "添加\(definition.name)")
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
                Text(title)
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

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { max(1, seconds / 60) },
            set: { seconds = max(1, $0) * 60 }
        )
    }

    var body: some View {
        Stepper(value: minutesBinding, in: 1...180, step: 5) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
                Text(ExerciseFormatting.shortDuration(seconds))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.Color.accent)
                    .monospacedDigit()
            }
        }
        .frame(minHeight: 44)
        .accessibilityValue(ExerciseFormatting.shortDuration(seconds))
    }
}
