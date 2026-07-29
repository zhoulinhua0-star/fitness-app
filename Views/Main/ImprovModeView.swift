//
//  ImprovModeView.swift
//  FitnessApp
//
//  "即兴模式" — Tiimo-inspired chat-style workout builder.
//  User picks muscle groups → taps exercises to add → starts training.
//  No pre-planning required.
//
//  Starting a workout injects the chosen exercises into today's logging
//  surface ("今日" tab) as ad-hoc improv exercises, so all check-in happens
//  through the one shared UI — there is no separate improv session screen.
//

import SwiftUI
import SwiftData

// MARK: - Floating mascot

private struct ImprovMascot: View {
    @State private var floating = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ground shadow that shrinks as the mascot rises
            Ellipse()
                .fill(Theme.Color.accent.opacity(0.18))
                .frame(width: 72, height: 18)
                .blur(radius: 8)
                .scaleEffect(floating ? 0.65 : 1.05)
                .offset(y: 6)

            // Body
            ZStack {
                // Blob shape
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Color.accentSoft,
                                Theme.Color.accent.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 72)

                // Eyes
                HStack(spacing: 22) {
                    Circle().fill(Theme.Color.textPrimary.opacity(0.75)).frame(width: 8, height: 8)
                    Circle().fill(Theme.Color.textPrimary.opacity(0.75)).frame(width: 8, height: 8)
                }
                .offset(y: -6)

                // Smile
                SmilePath()
                    .stroke(Theme.Color.textPrimary.opacity(0.5), lineWidth: 1.8)
                    .frame(width: 20, height: 8)
                    .offset(y: 9)
            }
            .offset(y: floating ? -16 : -4)
        }
        .frame(height: 100)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

private struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width / 2, y: rect.height)
        )
        return p
    }
}

// MARK: - Muscle group chip

private struct MuscleGroupChip: View {
    let group: MuscleGroupData
    let isSelected: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(group.emoji)
                .font(.system(size: 30))
            Text(AppLocalization.string(group.name))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.Color.accent : Theme.Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
        .background(isSelected ? Theme.Color.accentSoft : Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(
                    isSelected ? Theme.Color.accent : Theme.Color.hairline,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: Theme.Shadow.color, radius: 8, x: 0, y: 3)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Exercise suggestion row

private struct ExerciseSuggestionRow: View {
    let definition: ExerciseDefinition
    let groupTint: Color
    let isAdded: Bool
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var targetDurationSeconds: Int
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                ExerciseIconTile(definition: definition, tint: groupTint, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.localizedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(definition.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title2)
                        .foregroundStyle(isAdded ? Theme.Color.success : Theme.Color.accent)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAdded)
                }
                .buttonStyle(.plain)
            }

            if isAdded {
                Group {
                    if definition.trackingMode == .duration {
                        DurationSettingControl(title: "目标时长", seconds: $targetDurationSeconds)
                    } else {
                        HStack(spacing: Theme.Spacing.xl) {
                            ThemedStepper(title: "组数", value: $sets, range: 1...20)
                            ThemedStepper(title: "次数", value: $reps, range: 1...100)
                            Spacer()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.Spacing.m)
        .background(isAdded ? Theme.Color.tintMint : Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .stroke(
                    isAdded ? Theme.Color.success.opacity(0.4) : Theme.Color.hairline,
                    lineWidth: 1
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isAdded)
    }
}

// MARK: - Main view

struct ImprovModeView: View {
    /// Called after exercises are injected into today, so the parent can
    /// switch to the "今日" tab where the user logs the workout.
    var onStartWorkout: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var selectedGroups: Set<MuscleGroupData> = []
    @State private var sessionExercises: [ImprovEntry] = []
    @State private var customName = ""
    @State private var customActivityType: ExerciseActivityType = .strength
    @State private var customDurationSeconds = 20 * 60
    @State private var showingExercisePicker = false
    @FocusState private var customFieldFocused: Bool

    // Staggered entrance animation triggers
    @State private var mascotAppeared = false
    @State private var questionAppeared = false
    @State private var chipsAppeared = false

    /// Hand-typed lifts, shown in their own list under the recommendations.
    private var customEntries: [ImprovEntry] {
        sessionExercises.filter { $0.isCustom }
    }

    private var suggestedExercises: [(group: MuscleGroupData, definition: ExerciseDefinition)] {
        ExerciseLibrary.groups
            .filter { selectedGroups.contains($0) }
            .flatMap { group in
                group.exercises.compactMap { name in
                    ExerciseLibrary.definition(named: name).map { (group: group, definition: $0) }
                }
            }
    }

    private func isAdded(_ name: String) -> Bool {
        sessionExercises.contains(where: { $0.name == name })
    }

    private func setsBinding(for name: String) -> Binding<Int> {
        Binding(
            get: { sessionExercises.first(where: { $0.name == name })?.sets ?? 3 },
            set: { newValue in
                if let idx = sessionExercises.firstIndex(where: { $0.name == name }) {
                    sessionExercises[idx].sets = newValue
                }
            }
        )
    }

    private func repsBinding(for name: String) -> Binding<Int> {
        Binding(
            get: { sessionExercises.first(where: { $0.name == name })?.reps ?? 10 },
            set: { newValue in
                if let idx = sessionExercises.firstIndex(where: { $0.name == name }) {
                    sessionExercises[idx].reps = newValue
                }
            }
        )
    }

    private func durationBinding(for name: String) -> Binding<Int> {
        Binding(
            get: { sessionExercises.first(where: { $0.name == name })?.targetDurationSeconds ?? 20 * 60 },
            set: { newValue in
                if let idx = sessionExercises.firstIndex(where: { $0.name == name }) {
                    sessionExercises[idx].targetDurationSeconds = newValue
                }
            }
        )
    }

    private func setsBinding(id: UUID) -> Binding<Int> {
        Binding(
            get: { sessionExercises.first(where: { $0.id == id })?.sets ?? 3 },
            set: { newValue in
                if let idx = sessionExercises.firstIndex(where: { $0.id == id }) {
                    sessionExercises[idx].sets = newValue
                }
            }
        )
    }

    private func repsBinding(id: UUID) -> Binding<Int> {
        Binding(
            get: { sessionExercises.first(where: { $0.id == id })?.reps ?? 10 },
            set: { newValue in
                if let idx = sessionExercises.firstIndex(where: { $0.id == id }) {
                    sessionExercises[idx].reps = newValue
                }
            }
        )
    }

    private func durationBinding(id: UUID) -> Binding<Int> {
        Binding(
            get: { sessionExercises.first(where: { $0.id == id })?.targetDurationSeconds ?? 20 * 60 },
            set: { newValue in
                if let idx = sessionExercises.firstIndex(where: { $0.id == id }) {
                    sessionExercises[idx].targetDurationSeconds = newValue
                }
            }
        )
    }

    private func addCustomExercise() {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Skip if this lift is already staged (either custom or from the library).
        guard !sessionExercises.contains(where: { $0.name == trimmed }) else {
            customName = ""
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            sessionExercises.append(
                ImprovEntry(
                    name: trimmed,
                    sets: customActivityType == .cardio ? 0 : 3,
                    reps: customActivityType == .cardio ? 0 : 10,
                    activityType: customActivityType,
                    trackingMode: customActivityType == .cardio ? .duration : .setsAndReps,
                    targetDurationSeconds: customActivityType == .cardio ? customDurationSeconds : 0,
                    groupTint: Theme.Color.accentSoft,
                    isCustom: true
                )
            )
        }
        customName = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func removeEntry(_ entry: ImprovEntry) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            sessionExercises.removeAll { $0.id == entry.id }
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func toggle(_ definition: ExerciseDefinition, group: MuscleGroupData) {
        if let idx = sessionExercises.firstIndex(where: { $0.name == definition.name }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                _ = sessionExercises.remove(at: idx)
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sessionExercises.append(
                    ImprovEntry(
                        name: definition.name,
                        sets: definition.trackingMode == .duration ? 0 : definition.defaultSets,
                        reps: definition.trackingMode == .duration ? 0 : definition.defaultReps,
                        activityType: definition.activityType,
                        trackingMode: definition.trackingMode,
                        targetDurationSeconds: definition.trackingMode == .duration ? definition.defaultDurationSeconds : 0,
                        groupTint: group.tint
                    )
                )
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func addDefinition(_ definition: ExerciseDefinition) {
        guard !isAdded(definition.name) else { return }
        let tint = definition.activityType == .cardio ? Theme.Color.tintMint : Theme.Color.accentSoft
        sessionExercises.append(
            ImprovEntry(
                name: definition.name,
                sets: definition.trackingMode == .duration ? 0 : definition.defaultSets,
                reps: definition.trackingMode == .duration ? 0 : definition.defaultReps,
                activityType: definition.activityType,
                trackingMode: definition.trackingMode,
                targetDurationSeconds: definition.trackingMode == .duration ? definition.defaultDurationSeconds : 0,
                groupTint: tint
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {

                    // ── Mascot + question ──────────────────────────────
                    VStack(spacing: Theme.Spacing.l) {
                        ImprovMascot()
                            .opacity(mascotAppeared ? 1 : 0)
                            .scaleEffect(mascotAppeared ? 1 : 0.6)

                        Text("今天想练什么？")
                            .font(.displayMedium)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .opacity(questionAppeared ? 1 : 0)
                            .offset(y: questionAppeared ? 0 : 12)

                        Text("选择今天想练的部位")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .opacity(questionAppeared ? 1 : 0)
                    }
                    .padding(.top, Theme.Spacing.m)

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("搜索完整动作库", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.primaryCTA)

                    // ── Muscle group chips (3 × 2 grid) ───────────────
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Theme.Spacing.m),
                            GridItem(.flexible(), spacing: Theme.Spacing.m),
                            GridItem(.flexible(), spacing: Theme.Spacing.m)
                        ],
                        spacing: Theme.Spacing.m
                    ) {
                        ForEach(Array(ExerciseLibrary.groups.enumerated()), id: \.element.id) { idx, group in
                            MuscleGroupChip(group: group, isSelected: selectedGroups.contains(group))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedGroups.contains(group) {
                                            selectedGroups.remove(group)
                                            // Remove exercises from deselected group
                                            sessionExercises.removeAll { entry in
                                                group.exercises.contains(entry.name)
                                            }
                                        } else {
                                            selectedGroups.insert(group)
                                        }
                                    }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                                .opacity(chipsAppeared ? 1 : 0)
                                .offset(y: chipsAppeared ? 0 : 20)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.72)
                                        .delay(Double(idx) * 0.07),
                                    value: chipsAppeared
                                )
                        }
                    }

                    // ── Suggested exercises ────────────────────────────
                    if !selectedGroups.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            SectionPill(
                                title: "推荐动作",
                                count: sessionExercises.count > 0 ? sessionExercises.count : nil,
                                systemImage: "star.fill",
                                tint: Theme.Color.tintPeach
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(spacing: Theme.Spacing.s) {
                                ForEach(suggestedExercises, id: \.definition.id) { item in
                                    ExerciseSuggestionRow(
                                        definition: item.definition,
                                        groupTint: item.group.tint,
                                        isAdded: isAdded(item.definition.name),
                                        sets: setsBinding(for: item.definition.name),
                                        reps: repsBinding(for: item.definition.name),
                                        targetDurationSeconds: durationBinding(for: item.definition.name),
                                        onToggle: { toggle(item.definition, group: item.group) }
                                    )
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // ── Custom exercises (hand-typed) ──────────────────
                    customSection

                    Color.clear.frame(height: sessionExercises.isEmpty ? 0 : 100)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)

            // ── Floating start bar ─────────────────────────────────────
            if !sessionExercises.isEmpty {
                floatingStartBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionExercises.isEmpty)
            }
        }
        .onAppear { triggerEntranceAnimation() }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(
                selectedNames: Set(sessionExercises.map(\.name)),
                onSelect: addDefinition
            )
        }
    }

    // MARK: Start — inject exercises into today's logging surface

    private func startWorkout() {
        // Replace any existing improv exercises (stale or from a prior build)
        // so today's improv workout is exactly the current selection.
        if let existing = try? modelContext.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isImprov }
        )) {
            for exercise in existing {
                RestTimerCoordinator.shared.cancel(
                    timerID: RestTimerCoordinator.timerID(for: exercise.persistentModelID)
                )
                modelContext.delete(exercise)
            }
        }

        let now = Date.now
        for (index, entry) in sessionExercises.enumerated() {
            let exercise = Exercise(
                name: entry.name,
                sets: entry.sets,
                reps: entry.reps,
                order: index,
                activityType: entry.activityType,
                trackingMode: entry.trackingMode,
                targetDurationSeconds: entry.targetDurationSeconds,
                sessionDate: now,
                completedSetCount: 0,
                isImprov: true
            )
            modelContext.insert(exercise)
        }
        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sessionExercises = []
        selectedGroups = []
        onStartWorkout()
    }

    // MARK: Custom exercises

    private var customSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionPill(
                title: "自定义动作",
                count: customEntries.isEmpty ? nil : customEntries.count,
                systemImage: "square.and.pencil",
                tint: Theme.Color.tintBlue
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: Theme.Spacing.s) {
                // Input row
                HStack(spacing: Theme.Spacing.s) {
                    TextField(
                        "",
                        text: $customName,
                        prompt: Text("输入动作名称，如「农夫行走」")
                            .foregroundColor(Theme.Color.textSecondary)
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .focused($customFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(addCustomExercise)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 13)
                    .background(
                        Theme.Color.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    )

                    Button(action: addCustomExercise) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(Theme.Color.ctaLabel)
                            .frame(width: 48, height: 48)
                            .background(
                                Theme.Color.cta,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }

                Picker("训练类型", selection: $customActivityType) {
                    ForEach(ExerciseActivityType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if customActivityType == .cardio {
                    DurationSettingControl(title: "目标时长", seconds: $customDurationSeconds)
                }

                ForEach(customEntries) { entry in
                    customEntryRow(entry)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
    }

    private func customEntryRow(_ entry: ImprovEntry) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                ExerciseIconTile(
                    name: entry.name,
                    activityType: entry.activityType,
                    tint: entry.groupTint,
                    size: 44
                )

                Text(ExerciseLibrary.displayName(for: entry.name))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.textPrimary)

                Spacer()

                Button { removeEntry(entry) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if entry.trackingMode == .duration {
                DurationSettingControl(title: "目标时长", seconds: durationBinding(id: entry.id))
            } else {
                HStack(spacing: Theme.Spacing.xl) {
                    ThemedStepper(title: "组数", value: setsBinding(id: entry.id), range: 1...20)
                    ThemedStepper(title: "次数", value: repsBinding(id: entry.id), range: 1...100)
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Color.tintMint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .stroke(Theme.Color.success.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: Floating start bar

    private var floatingStartBar: some View {
        HStack(spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已选")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Color.textSecondary)
                Text("\(sessionExercises.count) 个动作")
                    .font(.headline)
                    .foregroundStyle(Theme.Color.textPrimary)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                startWorkout()
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Text("开始训练")
                    Image(systemName: "arrow.right")
                }
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.Color.ctaLabel)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, 14)
                .background(Theme.Color.cta, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.l)
        .background(
            Theme.Color.surface
                .shadow(.drop(color: Theme.Shadow.color, radius: 16, x: 0, y: -6)),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: Entrance animation

    private func triggerEntranceAnimation() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.05)) {
            mascotAppeared = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.35)) {
            questionAppeared = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.55)) {
            chipsAppeared = true
        }
    }
}
