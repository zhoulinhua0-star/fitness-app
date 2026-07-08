//
//  TemplateLibraryView.swift
//  FitnessApp
//
//  The template library ("模板库"): build reusable workout templates once, then
//  copy them into any day's schedule from the plan editor. Styled with the Tiimo
//  theme system to match PlanSetupView.
//

import SwiftUI
import SwiftData

struct TemplateLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [WorkoutTemplate]

    @State private var showingNameSheet = false
    @State private var newTemplateName = ""

    private var sortedTemplates: [WorkoutTemplate] {
        templates.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xl) {
                introCard

                if sortedTemplates.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        SectionPill(title: "我的模板", count: sortedTemplates.count,
                                    systemImage: "square.stack.3d.up.fill", tint: Theme.Color.tintBlue)
                        ForEach(sortedTemplates) { template in
                            NavigationLink(destination: TemplateEditorView(template: template)) {
                                TemplateCard(template: template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(action: { presentNameSheet() }) {
                    Label("新建模板", systemImage: "plus")
                }
                .buttonStyle(.primaryCTA)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xxl)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: templates.count)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle("模板库")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNameSheet) {
            TemplateNameSheet(name: $newTemplateName) { finalName in
                createTemplate(named: finalName)
            }
            .presentationDetents([.height(220)])
        }
    }

    private var introCard: some View {
        HStack(spacing: Theme.Spacing.m) {
            EmojiTile(emoji: "🗂️", tint: Theme.Color.tintBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text("训练模板")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("建好推日、拉日、腿日等模板，随时套用到任意一天")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .tiimoCard()
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("🗒️").font(.system(size: 40))
            Text("还没有模板")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
            Text("点击下方「新建模板」创建你的第一套课表")
                .font(.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
        .tiimoCard(padding: Theme.Spacing.xl)
    }

    // MARK: Actions

    private func presentNameSheet() {
        newTemplateName = ""
        showingNameSheet = true
    }

    private func createTemplate(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(WorkoutTemplate(name: name))
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Template card

struct TemplateCard: View {
    let template: WorkoutTemplate

    private var previewNames: [String] {
        template.sortedExercises.prefix(3).map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                EmojiTile(emoji: template.exercises.first.map { ExerciseEmoji.forName($0.name) } ?? "📋",
                          tint: Theme.Color.accentSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                    Text("\(template.exercises.count) 个动作 · \(template.totalSets) 组")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            if !previewNames.isEmpty {
                Text(previewNames.joined(separator: " · ")
                     + (template.exercises.count > 3 ? " …" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .tiimoCard()
    }
}

// MARK: - Name sheet (create / rename)

struct TemplateNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    var onCommit: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("模板名称")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Color.textPrimary)

            TextField("", text: $name,
                      prompt: Text("例如：推日 / 拉日 / 腿日").foregroundColor(Theme.Color.textSecondary))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Color.textPrimary)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .themedField()

            Button(action: commit) {
                Text("保存")
            }
            .buttonStyle(.primaryCTA)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Color.background.ignoresSafeArea())
        .onAppear { focused = true }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCommit(trimmed)
        dismiss()
    }
}

// MARK: - Single template editor

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: WorkoutTemplate

    @State private var newExerciseName = ""
    @State private var newSets = 4
    @State private var newReps = 12
    @State private var showingRenameSheet = false
    @State private var renameText = ""
    @FocusState private var nameFieldFocused: Bool

    private let quickPicks = ["卧推", "深蹲", "硬拉", "引体向上", "肩上推举", "杠铃划船", "二头弯举", "平板支撑"]

    private var sortedExercises: [TemplateExercise] {
        template.exercises.sorted { $0.order < $1.order }
    }

    private var totalSets: Int { template.exercises.reduce(0) { $0 + $1.sets } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xl) {
                if !template.exercises.isEmpty { summaryCard }
                exercisesSection
                composerSection
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xxl)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: template.exercises.count)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { presentRename() } label: { Label("重命名模板", systemImage: "pencil") }
                    if !template.exercises.isEmpty {
                        Button(role: .destructive, action: clearAllExercises) {
                            Label("清空动作", systemImage: "eraser")
                        }
                    }
                    Button(role: .destructive, action: deleteTemplate) {
                        Label("删除模板", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            TemplateNameSheet(name: $renameText) { finalName in
                template.name = finalName
                try? modelContext.save()
            }
            .presentationDetents([.height(220)])
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            stat(value: "\(template.exercises.count)", label: "动作", unit: "个")
            Divider().frame(height: 40).background(Theme.Color.hairline)
            stat(value: "\(totalSets)", label: "总组数", unit: "组")
        }
        .tiimoCard(padding: Theme.Spacing.l)
    }

    private func stat(value: String, label: String, unit: String) -> some View {
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

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "模板动作", count: template.exercises.count,
                        systemImage: "dumbbell.fill", tint: Theme.Color.tintPeach)

            if template.exercises.isEmpty {
                VStack(spacing: Theme.Spacing.m) {
                    Text("🗒️").font(.system(size: 36))
                    Text("还没有动作")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("在下方添加动作，构建这套模板")
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
                .tiimoCard(padding: Theme.Spacing.xl)
            } else {
                ForEach(Array(sortedExercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                    TemplateExerciseEditorCard(
                        exercise: exercise,
                        canMoveUp: index > 0,
                        canMoveDown: index < sortedExercises.count - 1,
                        onMoveUp: { moveExercise(at: index, by: -1) },
                        onMoveDown: { moveExercise(at: index, by: 1) },
                        onDelete: { deleteExercise(exercise) }
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
        }
    }

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(title: "添加新动作", systemImage: "plus.circle.fill", tint: Theme.Color.tintBlue)

            VStack(spacing: Theme.Spacing.l) {
                TextField("", text: $newExerciseName, prompt: Text("输入动作名称").foregroundColor(Theme.Color.textSecondary))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(addExercise)
                    .themedField()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(quickPicks, id: \.self) { pick in
                            Button {
                                newExerciseName = pick
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(pick)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(newExerciseName == pick ? Theme.Color.accent : Theme.Color.textSecondary)
                                    .padding(.horizontal, Theme.Spacing.m)
                                    .padding(.vertical, Theme.Spacing.s)
                                    .background(
                                        newExerciseName == pick ? Theme.Color.accentSoft : Theme.Color.surfaceMuted,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                HStack(spacing: Theme.Spacing.xl) {
                    ThemedStepper(title: "训练组数", value: $newSets, range: 1...10)
                    ThemedStepper(title: "每组次数", value: $newReps, range: 1...99)
                    Spacer()
                }

                Button(action: addExercise) {
                    Label("添加动作", systemImage: "plus")
                }
                .buttonStyle(.primaryCTA)
                .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .tiimoCard()
        }
    }

    // MARK: Actions

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            template.exercises.append(TemplateExercise(name: trimmed, sets: newSets, reps: newReps, order: template.exercises.count))
        }
        newExerciseName = ""
        nameFieldFocused = false
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func deleteExercise(_ exercise: TemplateExercise) {
        withAnimation {
            template.exercises.removeAll { $0.persistentModelID == exercise.persistentModelID }
            for (index, ex) in template.exercises.sorted(by: { $0.order < $1.order }).enumerated() {
                ex.order = index
            }
        }
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func moveExercise(at index: Int, by offset: Int) {
        var list = sortedExercises
        let target = index + offset
        guard list.indices.contains(index), list.indices.contains(target) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            list.swapAt(index, target)
            for (i, ex) in list.enumerated() { ex.order = i }
        }
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func clearAllExercises() {
        withAnimation { template.exercises.removeAll() }
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func presentRename() {
        renameText = template.name
        showingRenameSheet = true
    }

    private func deleteTemplate() {
        modelContext.delete(template)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
    }
}

// MARK: - Template exercise editor card

struct TemplateExerciseEditorCard: View {
    @Bindable var exercise: TemplateExercise
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                EmojiTile(emoji: ExerciseEmoji.forName(exercise.name))

                TextField("动作名称", text: $exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)

                Menu {
                    if canMoveUp { Button { onMoveUp() } label: { Label("上移", systemImage: "arrow.up") } }
                    if canMoveDown { Button { onMoveDown() } label: { Label("下移", systemImage: "arrow.down") } }
                    Button(role: .destructive, action: onDelete) { Label("删除动作", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Color.surfaceMuted, in: Circle())
                }
            }

            Divider().background(Theme.Color.hairline)

            HStack(spacing: Theme.Spacing.xl) {
                ThemedStepper(title: "组数", value: $exercise.sets, range: 1...20)
                ThemedStepper(title: "次数", value: $exercise.reps, range: 1...100)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("总计")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                    Text("\(exercise.sets * exercise.reps) 次")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                }
            }
        }
        .tiimoCard()
    }
}
