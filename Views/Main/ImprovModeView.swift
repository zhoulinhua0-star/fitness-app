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
            Text(group.name)
                .font(.system(size: 13, weight: .semibold))
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
    let name: String
    let groupTint: Color
    let isAdded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            EmojiTile(emoji: ExerciseEmoji.forName(name), tint: groupTint, size: 44)

            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(isAdded ? Theme.Color.success : Theme.Color.accent)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAdded)
            }
            .buttonStyle(.plain)
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

    // Staggered entrance animation triggers
    @State private var mascotAppeared = false
    @State private var questionAppeared = false
    @State private var chipsAppeared = false

    private var suggestedExercises: [(group: MuscleGroupData, name: String)] {
        ExerciseLibrary.groups
            .filter { selectedGroups.contains($0) }
            .flatMap { group in group.exercises.map { (group: group, name: $0) } }
    }

    private func isAdded(_ name: String) -> Bool {
        sessionExercises.contains(where: { $0.name == name })
    }

    private func toggle(_ name: String, group: MuscleGroupData) {
        if let idx = sessionExercises.firstIndex(where: { $0.name == name }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sessionExercises.remove(at: idx)
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sessionExercises.append(ImprovEntry(name: name, groupTint: group.tint))
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .opacity(questionAppeared ? 1 : 0)
                    }
                    .padding(.top, Theme.Spacing.m)

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
                                ForEach(suggestedExercises, id: \.name) { item in
                                    ExerciseSuggestionRow(
                                        name: item.name,
                                        groupTint: item.group.tint,
                                        isAdded: isAdded(item.name),
                                        onToggle: { toggle(item.name, group: item.group) }
                                    )
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Color.clear.frame(height: sessionExercises.isEmpty ? 0 : 100)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxl)
            }

            // ── Floating start bar ─────────────────────────────────────
            if !sessionExercises.isEmpty {
                floatingStartBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sessionExercises.isEmpty)
            }
        }
        .onAppear { triggerEntranceAnimation() }
    }

    // MARK: Start — inject exercises into today's logging surface

    private func startWorkout() {
        // Replace any existing improv exercises (stale or from a prior build)
        // so today's improv workout is exactly the current selection.
        if let existing = try? modelContext.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isImprov }
        )) {
            for exercise in existing { modelContext.delete(exercise) }
        }

        let now = Date.now
        for (index, entry) in sessionExercises.enumerated() {
            let exercise = Exercise(
                name: entry.name,
                sets: entry.sets,
                reps: entry.reps,
                order: index,
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

    // MARK: Floating start bar

    private var floatingStartBar: some View {
        HStack(spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text("已选")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Color.textSecondary)
                Text("\(sessionExercises.count) 个动作")
                    .font(.system(size: 17, weight: .bold))
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
                .font(.system(size: 16, weight: .bold))
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
