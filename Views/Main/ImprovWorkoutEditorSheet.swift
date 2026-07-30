//
//  ImprovWorkoutEditorSheet.swift
//  FitnessApp
//
//  Live editor for an active improv workout. Removed exercises stay in
//  SwiftData until the session ends so their completed sets remain in history.
//

import SwiftUI
import SwiftData

struct ImprovWorkoutEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Exercise> { $0.isImprov }) private var improvExercises: [Exercise]

    let onWorkoutChanged: () -> Void

    @State private var newExerciseName = ""
    @State private var newSets = 3
    @State private var newReps = 10
    @State private var newActivityType: ExerciseActivityType = .strength
    @State private var newDurationSeconds = 20 * 60
    @State private var showingExercisePicker = false
    @State private var lastRemoved: RemovedSnapshot?
    @State private var undoToken = UUID()
    @FocusState private var nameFieldFocused: Bool

    private struct RemovedSnapshot {
        let exercise: Exercise
        let order: Int
    }

    private var todayImprovExercises: [Exercise] {
        improvExercises
            .filter { $0.sessionDate.map { Calendar.current.isDateInToday($0) } ?? false }
            .sorted { $0.order < $1.order }
    }

    private var activeExercises: [Exercise] {
        todayImprovExercises.filter { !$0.isRemovedFromImprov }
    }

    private var trimmedName: String {
        newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var activeNameExists: Bool {
        activeExercises.contains {
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private var removedExerciseWithSameName: Exercise? {
        todayImprovExercises.first {
            $0.isRemovedFromImprov &&
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private var canAddExercise: Bool {
        !trimmedName.isEmpty && !activeNameExists
    }

    var body: some View {
        NavigationStack {
            List {
                workoutSection
                addExerciseSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("编辑本次训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let lastRemoved {
                    undoBanner(for: lastRemoved)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: undoToken) {
                guard lastRemoved != nil else { return }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    lastRemoved = nil
                }
            }
        }
        .appKeyboardToolbar()
        .presentationBackground(Theme.Color.background)
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(
                selectedNames: Set(activeExercises.map(\.name)),
                onSelect: selectDefinition
            )
        }
    }

    private var workoutSection: some View {
        Section {
            if activeExercises.isEmpty {
                VStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "dumbbell")
                        .font(.title.weight(.medium))
                        .foregroundStyle(Theme.Color.accent)
                    Text("没有待训练动作")
                        .font(.headline)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("可以继续在下方添加动作")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.l)
                .listRowBackground(Theme.Color.surface)
            } else {
                ForEach(Array(activeExercises.enumerated()), id: \.element.persistentModelID) { index, exercise in
                    ImprovEditorExerciseRow(
                        exercise: exercise,
                        canMoveUp: index > 0,
                        canMoveDown: index < activeExercises.count - 1,
                        onMoveUp: { moveExercise(at: index, by: -1) },
                        onMoveDown: { moveExercise(at: index, by: 1) },
                        onRemove: { removeExercise(exercise) }
                    )
                    .listRowBackground(Theme.Color.surface)
                }
                .onDelete(perform: removeExercises)
            }
        } header: {
            Text("本次训练 · \(activeExercises.count) 个动作")
        } footer: {
            Text("移出已开始的动作时，已完成的训练记录会保留")
        }
    }

    private var addExerciseSection: some View {
        Section("添加动作") {
            Button {
                showingExercisePicker = true
            } label: {
                HStack {
                    Label("从动作库选择", systemImage: "books.vertical")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .foregroundStyle(Theme.Color.accent)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            TextField("或输入自定义动作名称", text: $newExerciseName)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit(addExercise)
                .themedField(isFocused: nameFieldFocused)

            if activeNameExists {
                Label("这个动作已经在本次训练中", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            Picker("训练类型", selection: $newActivityType) {
                ForEach(ExerciseActivityType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if newActivityType == .cardio {
                DurationSettingControl(title: "目标时长", seconds: $newDurationSeconds)
                    .padding(.vertical, Theme.Spacing.s)
            } else {
                HStack(spacing: Theme.Spacing.xl) {
                    ThemedStepper(title: "训练组数", value: $newSets, range: 1...20)
                    ThemedStepper(title: "每组次数", value: $newReps, range: 1...100)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Spacing.s)
            }

            Button(action: addExercise) {
                Label(
                    removedExerciseWithSameName == nil ? "添加到本次训练" : "重新加入本次训练",
                    systemImage: "plus"
                )
            }
            .buttonStyle(.primaryCTA)
            .disabled(!canAddExercise)
            .opacity(canAddExercise ? 1 : 0.5)
            .listRowInsets(
                EdgeInsets(
                    top: Theme.Spacing.m,
                    leading: Theme.Spacing.l,
                    bottom: Theme.Spacing.m,
                    trailing: Theme.Spacing.l
                )
            )
        }
        .listRowBackground(Theme.Color.surface)
    }

    private func addExercise() {
        guard canAddExercise else { return }

        if let removed = removedExerciseWithSameName {
            removed.isRemovedFromImprov = false
            removed.activityType = newActivityType
            removed.trackingMode = newActivityType == .cardio ? .duration : .setsAndReps
            removed.targetDurationSeconds = newActivityType == .cardio ? newDurationSeconds : 0
            removed.sets = newActivityType == .cardio ? 0 : max(newSets, removed.completedSetCount)
            removed.reps = newActivityType == .cardio ? 0 : newReps
            removed.order = activeExercises.count
            persistChanges()
        } else {
            let exercise = Exercise(
                name: trimmedName,
                sets: newActivityType == .cardio ? 0 : newSets,
                reps: newActivityType == .cardio ? 0 : newReps,
                order: activeExercises.count,
                activityType: newActivityType,
                trackingMode: newActivityType == .cardio ? .duration : .setsAndReps,
                targetDurationSeconds: newActivityType == .cardio ? newDurationSeconds : 0,
                sessionDate: .now,
                isImprov: true
            )
            modelContext.insert(exercise)
            persistChanges(including: exercise)
        }

        newExerciseName = ""
        nameFieldFocused = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func selectDefinition(_ definition: ExerciseDefinition) {
        newExerciseName = definition.name
        newActivityType = definition.activityType
        newSets = definition.defaultSets
        newReps = definition.defaultReps
        newDurationSeconds = definition.defaultDurationSeconds
        nameFieldFocused = false
    }

    private func moveExercise(at index: Int, by offset: Int) {
        var list = activeExercises
        let destination = index + offset
        guard list.indices.contains(index), list.indices.contains(destination) else { return }
        list.swapAt(index, destination)
        applyOrder(to: list)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func applyOrder(to exercises: [Exercise]) {
        withAnimation(.snappy) {
            for (index, exercise) in exercises.enumerated() {
                exercise.order = index
            }
        }
        persistChanges()
    }

    private func removeExercises(at offsets: IndexSet) {
        let list = activeExercises
        guard let firstIndex = offsets.first, list.indices.contains(firstIndex) else { return }

        for index in offsets.sorted(by: >) where list.indices.contains(index) {
            let exercise = list[index]
            lastRemoved = RemovedSnapshot(exercise: exercise, order: exercise.order)
            RestTimerCoordinator.shared.cancel(
                timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
            )
            CardioGoalCoordinator.shared.cancel(
                timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
            )
            exercise.isRemovedFromImprov = true
        }
        repackActiveExerciseOrder()
        finishRemovalFeedback(name: list[firstIndex].name)
    }

    private func removeExercise(_ exercise: Exercise) {
        withAnimation(.snappy) {
            lastRemoved = RemovedSnapshot(exercise: exercise, order: exercise.order)
            RestTimerCoordinator.shared.cancel(
                timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
            )
            CardioGoalCoordinator.shared.cancel(
                timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
            )
            exercise.isRemovedFromImprov = true
        }
        repackActiveExerciseOrder()
        finishRemovalFeedback(name: exercise.name)
    }

    private func repackActiveExerciseOrder() {
        for (index, exercise) in activeExercises
            .filter({ !$0.isRemovedFromImprov })
            .sorted(by: { $0.order < $1.order })
            .enumerated() {
            exercise.order = index
        }
    }

    private func finishRemovalFeedback(name: String) {
        persistChanges()
        undoToken = UUID()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        UIAccessibility.post(notification: .announcement, argument: "已将\(name)移出本次训练")
    }

    private func undoRemoval(_ snapshot: RemovedSnapshot) {
        var list = activeExercises
        snapshot.exercise.isRemovedFromImprov = false
        let insertionIndex = min(max(snapshot.order, 0), list.count)
        list.insert(snapshot.exercise, at: insertionIndex)
        for (index, exercise) in list.enumerated() {
            exercise.order = index
        }
        lastRemoved = nil
        persistChanges()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func persistChanges(including addedExercise: Exercise? = nil) {
        var exercises = todayImprovExercises
        if let addedExercise,
           !exercises.contains(where: { $0.persistentModelID == addedExercise.persistentModelID }) {
            exercises.append(addedExercise)
        }

        if let session = WorkoutHistoryManager.fetchTodaySession(context: modelContext) {
            WorkoutHistoryManager.syncSessionMetadata(
                session: session,
                dayName: "即兴训练",
                exercises: exercises
            )
        }
        try? modelContext.save()
        onWorkoutChanged()
    }

    private func undoBanner(for snapshot: RemovedSnapshot) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Color.success)
            Text("已移出「\(snapshot.exercise.name)」")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Color.textPrimary)
                .lineLimit(1)
            Spacer()
            Button("撤销") {
                undoRemoval(snapshot)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Color.accent)
            .frame(minHeight: 44)
        }
        .padding(.leading, Theme.Spacing.l)
        .padding(.trailing, Theme.Spacing.s)
        .background(Theme.Color.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.Color.hairline, lineWidth: 1))
        .shadow(color: Theme.Shadow.color, radius: 12, x: 0, y: 5)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
    }
}

private struct ImprovEditorExerciseRow: View {
    let exercise: Exercise
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ExerciseIconTile(
                name: exercise.name,
                activityType: exercise.activityType,
                size: 40
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(ExerciseLibrary.displayName(for: exercise.name))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(progressDescription)
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.s)

            Menu {
                if canMoveUp {
                    Button(action: onMoveUp) {
                        Label("上移", systemImage: "arrow.up")
                    }
                }
                if canMoveDown {
                    Button(action: onMoveDown) {
                        Label("下移", systemImage: "arrow.down")
                    }
                }
                Button(role: .destructive, action: onRemove) {
                    Label("从本次训练移出", systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("编辑\(exercise.name)")
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var progressDescription: String {
        if exercise.isCardio {
            let elapsed = exercise.cardioElapsedSeconds()
            if exercise.isFullyCompletedToday {
                return AppLocalization.format(
                    "已完成 · %@",
                    ExerciseFormatting.shortDuration(elapsed)
                )
            }
            return AppLocalization.format(
                "目标 %@",
                ExerciseFormatting.shortDuration(exercise.targetDurationSeconds)
            )
        }
        if exercise.effectiveCompletedSetCount > 0 {
            return AppLocalization.format(
                "已完成 %lld / %lld 组 · 每组 %lld 次",
                exercise.effectiveCompletedSetCount,
                exercise.sets,
                exercise.reps
            )
        }
        return AppLocalization.format(
            "%lld 组 · 每组 %lld 次",
            exercise.sets,
            exercise.reps
        )
    }
}
