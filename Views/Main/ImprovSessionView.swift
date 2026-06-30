//
//  ImprovSessionView.swift
//  FitnessApp
//
//  Full-screen training view for improv sessions.
//  Tracks set-by-set progress with tap-dot UI; saves a WorkoutSession
//  and SetLogs to SwiftData on completion.
//

import SwiftUI
import SwiftData

struct ImprovSessionView: View {
    // Exercises passed in from ImprovModeView
    let initialExercises: [ImprovEntry]
    let onComplete: () -> Void

    @State private var exercises: [ImprovEntry]
    @State private var activeIndex: Int? = nil
    @State private var showRestTimer = false
    @State private var restTimerToken = UUID()
    @State private var showCompletionSheet = false
    @State private var startedAt = Date.now

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var settings: AppSettings { AppSettings.shared }

    private var totalSets: Int      { exercises.reduce(0) { $0 + $1.sets } }
    private var completedSets: Int  { exercises.reduce(0) { $0 + $1.completedSets } }
    private var progress: Double    { totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0 }
    private var allDone: Bool       { exercises.allSatisfy(\.isFullyDone) }

    init(exercises: [ImprovEntry], onComplete: @escaping () -> Void) {
        self.initialExercises = exercises
        self.onComplete = onComplete
        self._exercises = State(initialValue: exercises)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.xl) {
                        sessionHeader
                        progressCard

                        ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, _ in
                            exerciseCard(at: idx)
                        }

                        if allDone {
                            finishButton
                                .transition(.scale.combined(with: .opacity))
                        }

                        Color.clear.frame(height: Theme.Spacing.xxl)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.m)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: allDone)
                }
            }
            .navigationTitle("即兴训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("结束") {
                        saveSession()
                        dismiss()
                        onComplete()
                    }
                    .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
    }

    // MARK: Session header

    private var sessionHeader: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("即兴训练")
                .font(.displayLarge)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(Date.now, format: .dateTime.month(.wide).day().year())
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Progress card

    private var progressCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("训练进度")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
                Text("\(completedSets) / \(totalSets) 组")
                    .font(.display(28, weight: .bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("\(exercises.filter(\.isFullyDone).count) / \(exercises.count) 个动作已完成")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            RingProgressView(progress: progress, size: 64)
        }
        .tiimoCard()
    }

    // MARK: Exercise card

    @ViewBuilder
    private func exerciseCard(at idx: Int) -> some View {
        let exercise = exercises[idx]
        let isActive = activeIndex == idx

        VStack(spacing: Theme.Spacing.m) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    activeIndex = isActive ? nil : idx
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    EmojiTile(emoji: ExerciseEmoji.forName(exercise.name), tint: exercise.groupTint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .semibold))
                            .strikethrough(exercise.isFullyDone, color: Theme.Color.textSecondary)
                            .foregroundStyle(exercise.isFullyDone ? Theme.Color.textSecondary : Theme.Color.textPrimary)
                        Text("\(exercise.completedSets) / \(exercise.sets) 组 · \(exercise.reps) 次/组")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Color.textSecondary)
                        ProgressView(value: exercise.progress)
                            .tint(Theme.Color.accent)
                            .animation(nil, value: exercise.progress)
                    }

                    Spacer()

                    CircleCheck(isComplete: exercise.isFullyDone)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded: set dots + rest timer
            if isActive {
                VStack(spacing: Theme.Spacing.m) {
                    Divider().background(Theme.Color.hairline)
                    setDots(for: idx)

                    if showRestTimer && activeIndex == idx && !exercise.isFullyDone {
                        RestTimerView(
                            durationSeconds: settings.defaultRestSeconds,
                            onSkip: { showRestTimer = false },
                            onComplete: { showRestTimer = false }
                        )
                        .id(restTimerToken)
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .tiimoCard(highlighted: isActive)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isActive)
    }

    // MARK: Set dots

    private func setDots(for idx: Int) -> some View {
        let exercise = exercises[idx]
        let completed = exercise.completedSets

        return VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(1...max(1, exercise.sets), id: \.self) { setNum in
                    let isDone = setNum <= completed
                    let isNext = setNum == completed + 1

                    Button {
                        guard !exercises[idx].isFullyDone || setNum == completed else { return }
                        if isDone && setNum == completed {
                            // Undo last set
                            exercises[idx].completedSets -= 1
                            showRestTimer = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } else if isNext {
                            exercises[idx].completedSets += 1
                            if !exercises[idx].isFullyDone {
                                showRestTimer = true
                                restTimerToken = UUID()
                                NotificationManager.scheduleRestEndNotification(
                                    after: settings.defaultRestSeconds,
                                    exerciseName: exercises[idx].name
                                )
                            } else {
                                showRestTimer = false
                                NotificationManager.cancelRestEndNotification()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isDone ? Theme.Color.accent : (isNext ? Theme.Color.accentSoft : Theme.Color.surfaceMuted))
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(
                                isNext ? Theme.Color.accent : Color.clear,
                                lineWidth: 2
                            )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDone)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isDone && !isNext)
                    .opacity(!isDone && !isNext ? 0.4 : 1)
                }
            }

            Text("点击圆点记录完成 · 再次点击可撤销")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    // MARK: Finish button

    private var finishButton: some View {
        Button {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            saveSession()
            dismiss()
            onComplete()
        } label: {
            Label("完成训练 🎉", systemImage: "checkmark.seal.fill")
        }
        .buttonStyle(.primaryCTA)
    }

    // MARK: Save to SwiftData

    private func saveSession() {
        let totalPlanned = exercises.reduce(0) { $0 + $1.sets }
        let totalCompleted = exercises.reduce(0) { $0 + $1.completedSets }
        guard totalCompleted > 0 else { return }

        let session = WorkoutSession(
            sessionDate: .now,
            dayName: "即兴",
            plannedSetCount: totalPlanned,
            completedSetCount: totalCompleted,
            isComplete: allDone,
            startedAt: startedAt,
            completedAt: .now
        )
        modelContext.insert(session)

        for exercise in exercises {
            for setIdx in 1...max(1, exercise.completedSets) {
                guard setIdx <= exercise.completedSets else { break }
                let log = SetLog(
                    exerciseName: exercise.name,
                    setIndex: setIdx,
                    reps: exercise.reps
                )
                log.session = session
                modelContext.insert(log)
            }
        }

        try? modelContext.save()
    }
}
