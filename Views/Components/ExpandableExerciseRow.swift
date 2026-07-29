import SwiftUI
import SwiftData

struct ExpandableExerciseRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var exercise: Exercise
    let session: WorkoutSession
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSetProgressChanged: () -> Void

    @State private var restTimers = RestTimerCoordinator.shared
    @State private var todayRestSeconds: Int?
    @State private var showRestDurationPicker = false

    private static let legacyRestTimerEndDateKey = "restTimerEndDate"
    private static let legacyRestTimerExerciseNameKey = "restTimerExerciseName"
    private static let restOverrideDayKey = "restOverrideDay"
    private static let restOverridesKey = "restOverrides"
    
    private var settings: AppSettings { AppSettings.shared }

    private var activeRestTimer: ActiveRestTimer? {
        restTimers.timer(for: restTimerID)
    }

    private var completedRestTimer: CompletedRestTimer? {
        restTimers.completion(for: restTimerID)
    }

    private var effectiveRestSeconds: Int {
        todayRestSeconds ?? exercise.restSeconds ?? settings.defaultRestSeconds
    }
    
    private var setRowIDs: [ExerciseSetRowID] {
        guard exercise.sets > 0 else { return [] }
        return (1...exercise.sets).map {
            ExerciseSetRowID(exerciseID: exercise.persistentModelID, setNumber: $0)
        }
    }
    
    private var completedSets: Int {
        exercise.effectiveCompletedSetCount
    }
    
    private var isFullyCompleted: Bool {
        exercise.isFullyCompletedToday
    }
    
    private var lastTimeSummary: String? {
        if exercise.isCardio {
            return WorkoutHistoryManager.lastCardioPerformanceSummary(context: modelContext, exerciseName: exercise.name)
        }
        return WorkoutHistoryManager.lastPerformanceSummary(context: modelContext, exerciseName: exercise.name)
    }
    
    private static let expandSpring = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleExpand) {
                headerContent
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                setPanel
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .move(edge: .top))
                                .combined(with: .scale(scale: 0.97, anchor: .top)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.98, anchor: .top))
                        )
                    )
            }
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(isExpanded ? Theme.Color.accent : Theme.Color.hairline,
                        lineWidth: isExpanded ? 1.5 : 1)
        )
        .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
        .animation(Self.expandSpring, value: isExpanded)
        .sensoryFeedback(.selection, trigger: isExpanded)
        .onAppear {
            guard !exercise.isCardio else { return }
            todayRestSeconds = loadTodayRestOverride()
            migrateLegacyRestTimerIfNeeded()
            restTimers.register(timerID: restTimerID, exerciseName: exercise.name)
            if isFullyCompleted {
                restTimers.cancel(timerID: restTimerID)
            }
        }
    }
    
    private var headerContent: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        ExerciseIconTile(name: exercise.name, activityType: exercise.activityType)
                        exerciseTextContent
                        CircleCheck(isComplete: isFullyCompleted)
                    }

                    if !exercise.isCardio, let timer = activeRestTimer, !isFullyCompleted {
                        RestTimerBadge(endDate: timer.endDate)
                    } else if !exercise.isCardio, completedRestTimer != nil, !isFullyCompleted {
                        RestReadyBadge()
                    }
                }
            } else {
                HStack(spacing: Theme.Spacing.m) {
                    ExerciseIconTile(name: exercise.name, activityType: exercise.activityType)
                    exerciseTextContent
                    Spacer(minLength: 8)

                    if !exercise.isCardio, let timer = activeRestTimer, !isFullyCompleted {
                        RestTimerBadge(endDate: timer.endDate)
                    } else if !exercise.isCardio, completedRestTimer != nil, !isFullyCompleted {
                        RestReadyBadge()
                    }

                    CircleCheck(isComplete: isFullyCompleted)
                }
            }
        }
    }

    private var exerciseTextContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .appScaledFont(size: 17, relativeTo: .headline, weight: .semibold)
                .strikethrough(isFullyCompleted, color: Theme.Color.textSecondary)
                .foregroundStyle(isFullyCompleted ? Theme.Color.textSecondary : Theme.Color.textPrimary)

            if exercise.isCardio {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = exercise.cardioElapsedSeconds(at: context.date)
                    Text(cardioHeaderDescription(elapsed: elapsed))
                        .font(.subheadline)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .monospacedDigit()
                }
            } else {
                Text("\(completedSets) / \(exercise.sets) 组 · \(exercise.reps) 次/组")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            if let lastTimeSummary {
                Text(lastTimeSummary)
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            if exercise.isCardio {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ProgressView(value: exercise.cardioProgress(at: context.date))
                        .tint(exercise.isFullyCompletedToday ? Theme.Color.success : Theme.Color.accent)
                }
            } else {
                ProgressView(value: exercise.setProgress)
                    .tint(Theme.Color.accent)
                    .animation(nil, value: exercise.setProgress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var setPanel: some View {
        Group {
            if exercise.isCardio {
                cardioPanel
            } else {
                strengthSetPanel
            }
        }
    }

    private var strengthSetPanel: some View {
        VStack(spacing: 8) {
            Divider()

            Button {
                showRestDurationPicker = true
            } label: {
                HStack {
                    Label("休息时长", systemImage: "timer")
                    Spacer()
                    Text(formattedDuration(effectiveRestSeconds))
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Theme.Color.surfaceMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("调整此动作的休息时长")
            .sheet(isPresented: $showRestDurationPicker) {
                RestDurationPickerSheet(
                    initialSeconds: effectiveRestSeconds,
                    canSaveToPlan: !exercise.isImprov,
                    onUseToday: { saveTodayRestOverride($0) },
                    onSaveToPlan: { saveRestDurationToPlan($0) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            
            ForEach(setRowIDs, id: \.self) { rowID in
                setRow(setNumber: rowID.setNumber)
            }
            .id(exercise.sets)
            
            if let timer = activeRestTimer, !isFullyCompleted {
                RestTimerView(
                    endDate: timer.endDate,
                    nextSetNumber: completedSets + 1,
                    onSkip: { skipRestTimer() },
                    onEndDateChanged: { updateRestTimerEndDate($0) }
                )
            } else if let completion = completedRestTimer, !isFullyCompleted {
                RestReadyView(
                    nextSetNumber: completedSets + 1,
                    wasSkipped: completion.reason == .skipped
                )
            }
            
            if !isFullyCompleted {
                Button(action: completeAllRemaining) {
                    Text("全部完成")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
    }

    private var cardioPanel: some View {
        VStack(spacing: Theme.Spacing.m) {
            Divider()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = exercise.cardioElapsedSeconds(at: context.date)
                let reachedGoal = elapsed >= exercise.targetDurationSeconds

                VStack(spacing: Theme.Spacing.m) {
                    VStack(spacing: 4) {
                        Text(ExerciseFormatting.duration(elapsed))
                            .appScaledFont(size: 40, relativeTo: .largeTitle, weight: .bold, design: .rounded)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("目标 \(ExerciseFormatting.duration(exercise.targetDurationSeconds))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .monospacedDigit()
                    }

                    ProgressView(value: exercise.cardioProgress(at: context.date))
                        .tint(reachedGoal ? Theme.Color.success : Theme.Color.accent)

                    if reachedGoal && !exercise.isFullyCompletedToday {
                        Label("目标已达到，可以继续", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Color.success)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Theme.Color.tintMint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityLabel("有氧目标已达到，可以继续训练")
                    }

                    cardioControls(elapsed: elapsed)
                }
            }
        }
    }

    @ViewBuilder
    private func cardioControls(elapsed: Int) -> some View {
        if exercise.isFullyCompletedToday {
            VStack(spacing: Theme.Spacing.s) {
                Label("已完成并保存 \(ExerciseFormatting.shortDuration(elapsed))", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Color.success)

                Button {
                    resetCardio()
                } label: {
                    Label("重新计时", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        } else if exercise.cardioStartedAt != nil {
            HStack(spacing: Theme.Spacing.s) {
                Button {
                    pauseCardio()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    finishCardio()
                } label: {
                    Label("结束并保存", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
            }
        } else if elapsed > 0 {
            HStack(spacing: Theme.Spacing.s) {
                Button {
                    startCardio()
                } label: {
                    Label("继续", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    finishCardio()
                } label: {
                    Label("结束并保存", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
            }
        } else {
            Button {
                startCardio()
            } label: {
                Label("开始计时", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Color.accent)
        }
    }

    private func cardioHeaderDescription(elapsed: Int) -> String {
        if exercise.isFullyCompletedToday {
            return "已完成 · \(ExerciseFormatting.shortDuration(elapsed))"
        }
        if exercise.cardioStartedAt != nil {
            return "\(ExerciseFormatting.duration(elapsed)) / \(ExerciseFormatting.duration(exercise.targetDurationSeconds)) · 计时中"
        }
        if elapsed > 0 {
            return "\(ExerciseFormatting.duration(elapsed)) / \(ExerciseFormatting.duration(exercise.targetDurationSeconds)) · 已暂停"
        }
        return "目标 \(ExerciseFormatting.shortDuration(exercise.targetDurationSeconds))"
    }

    private func startCardio() {
        exercise.startCardio()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSetProgressChanged()
    }

    private func pauseCardio() {
        exercise.pauseCardio()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSetProgressChanged()
    }

    private func finishCardio() {
        let duration = exercise.finishCardio()
        WorkoutHistoryManager.logCardio(
            context: modelContext,
            session: session,
            exercise: exercise,
            durationSeconds: duration
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSetProgressChanged()
    }

    private func resetCardio() {
        WorkoutHistoryManager.removeCardioLog(
            context: modelContext,
            session: session,
            exerciseName: exercise.name
        )
        exercise.resetCardio()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        onSetProgressChanged()
    }
    
    private func setRow(setNumber: Int) -> some View {
        let state = setState(for: setNumber)
        
        return Button(action: { handleSetTap(setNumber: setNumber, state: state) }) {
            setRowContent(setNumber: setNumber, state: state)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(state.backgroundColor)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(state == .upcoming)
        .opacity(state == .upcoming ? 0.4 : 1)
    }
    
    private func setRowContent(setNumber: Int, state: SetState) -> some View {
        HStack {
            Image(systemName: state.iconName)
                .font(.body.weight(.semibold))
                .foregroundColor(state.iconColor)
                .frame(width: 24)
            
            Text("第 \(setNumber) 组")
                .font(.subheadline.weight(state == .next ? .semibold : .regular))
                .foregroundColor(state.titleColor)
            
            Spacer()
            
            Text("\(exercise.reps) 次")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private enum SetState {
        case completed, next, upcoming
        
        var iconName: String {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .next, .upcoming: return "circle"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .completed, .next: return .accentColor
            case .upcoming: return .gray
            }
        }
        
        var titleColor: Color {
            switch self {
            case .completed, .upcoming: return .secondary
            case .next: return .primary
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .completed, .upcoming: return Theme.Color.surfaceMuted
            case .next: return Color.accentColor.opacity(0.12)
            }
        }
    }
    
    private func setState(for setNumber: Int) -> SetState {
        if setNumber <= completedSets { return .completed }
        if setNumber == completedSets + 1 { return .next }
        return .upcoming
    }
    
    private func handleSetTap(setNumber: Int, state: SetState) {
        guard isExpanded else { return }
        
        switch state {
        case .next:
            completeNextSet()
        case .completed where setNumber == completedSets:
            undoLastSet()
        case .completed, .upcoming:
            break
        }
    }
    
    private func startRestTimerIfNeeded(wasFullyCompleted: Bool) {
        if !wasFullyCompleted && exercise.isFullyCompletedToday {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            cancelRestTimer()
        } else if !exercise.isFullyCompletedToday {
            let restSeconds = effectiveRestSeconds
            restTimers.start(
                timerID: restTimerID,
                exerciseName: exercise.name,
                seconds: restSeconds
            )
        }
    }

    private func cancelRestTimer() {
        restTimers.cancel(timerID: restTimerID)
    }

    private func skipRestTimer() {
        restTimers.skip(timerID: restTimerID)
    }

    private func updateRestTimerEndDate(_ endDate: Date) {
        restTimers.adjust(timerID: restTimerID, endDate: endDate)
    }

    private var restOverrideID: String {
        "\(exercise.order)#\(exercise.name)"
    }

    private func loadTodayRestOverride() -> Int? {
        let defaults = UserDefaults.standard
        let todayStamp = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        guard defaults.double(forKey: Self.restOverrideDayKey) == todayStamp else {
            defaults.set(todayStamp, forKey: Self.restOverrideDayKey)
            defaults.removeObject(forKey: Self.restOverridesKey)
            return nil
        }
        return defaults.dictionary(forKey: Self.restOverridesKey)?[restOverrideID] as? Int
    }

    private func saveTodayRestOverride(_ seconds: Int) {
        let defaults = UserDefaults.standard
        let todayStamp = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        var overrides = defaults.dictionary(forKey: Self.restOverridesKey) ?? [:]
        overrides[restOverrideID] = seconds
        defaults.set(todayStamp, forKey: Self.restOverrideDayKey)
        defaults.set(overrides, forKey: Self.restOverridesKey)
        todayRestSeconds = seconds
        showRestDurationPicker = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveRestDurationToPlan(_ seconds: Int) {
        exercise.restSeconds = seconds
        removeTodayRestOverride()
        try? modelContext.save()
        showRestDurationPicker = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func removeTodayRestOverride() {
        let defaults = UserDefaults.standard
        var overrides = defaults.dictionary(forKey: Self.restOverridesKey) ?? [:]
        overrides.removeValue(forKey: restOverrideID)
        defaults.set(overrides, forKey: Self.restOverridesKey)
        todayRestSeconds = nil
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var restTimerID: String {
        RestTimerCoordinator.timerID(for: exercise.persistentModelID)
    }

    private func migrateLegacyRestTimerIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Self.legacyRestTimerExerciseNameKey) == exercise.name else {
            return
        }

        let interval = defaults.double(forKey: Self.legacyRestTimerEndDateKey)
        NotificationManager.cancelLegacyRestEndNotification()
        if interval > Date().timeIntervalSince1970 {
            restTimers.restore(
                timerID: restTimerID,
                exerciseName: exercise.name,
                endDate: Date(timeIntervalSince1970: interval)
            )
        }
        defaults.removeObject(forKey: Self.legacyRestTimerEndDateKey)
        defaults.removeObject(forKey: Self.legacyRestTimerExerciseNameKey)
    }
    
    private func completeNextSet() {
        guard isExpanded else { return }
        
        let wasFullyCompleted = isFullyCompleted
        let nextSetIndex = completedSets + 1
        guard exercise.completeNextSet() else { return }
        
        WorkoutHistoryManager.logSet(
            context: modelContext,
            session: session,
            exercise: exercise,
            setIndex: nextSetIndex,
            weight: nil
        )
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        startRestTimerIfNeeded(wasFullyCompleted: wasFullyCompleted)
        onSetProgressChanged()
    }
    
    private func undoLastSet() {
        guard isExpanded else { return }
        
        guard exercise.undoLastSet() else { return }
        WorkoutHistoryManager.undoLastSetLog(
            context: modelContext,
            session: session,
            exerciseName: exercise.name
        )
        cancelRestTimer()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSetProgressChanged()
    }
    
    private func completeAllRemaining() {
        guard isExpanded else { return }
        
        let wasFullyCompleted = isFullyCompleted
        let startIndex = completedSets + 1
        exercise.completeAllRemainingSets()
        
        WorkoutHistoryManager.logRemainingSets(
            context: modelContext,
            session: session,
            exercise: exercise,
            startingAt: startIndex,
            weight: nil
        )
        
        cancelRestTimer()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if !wasFullyCompleted && exercise.isFullyCompletedToday {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        onSetProgressChanged()
    }
}

private struct ExerciseSetRowID: Hashable {
    let exerciseID: PersistentIdentifier
    let setNumber: Int
}

private struct RestDurationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let canSaveToPlan: Bool
    let onUseToday: (Int) -> Void
    let onSaveToPlan: (Int) -> Void

    @State private var selectedSeconds: Int

    private let presets = [30, 60, 90, 120, 180]

    init(
        initialSeconds: Int,
        canSaveToPlan: Bool,
        onUseToday: @escaping (Int) -> Void,
        onSaveToPlan: @escaping (Int) -> Void
    ) {
        self.canSaveToPlan = canSaveToPlan
        self.onUseToday = onUseToday
        self.onSaveToPlan = onSaveToPlan
        _selectedSeconds = State(initialValue: initialSeconds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text("设置休息时长")
                    .appScaledFont(size: 18, relativeTo: .headline, weight: .bold)
                    .foregroundStyle(Theme.Color.textPrimary)

                Text(formattedDuration(selectedSeconds))
                    .appScaledFont(size: 42, relativeTo: .largeTitle, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Color.accent)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 64), spacing: Theme.Spacing.s)],
                    spacing: Theme.Spacing.s
                ) {
                    ForEach(presets, id: \.self) { seconds in
                        Button(shortDuration(seconds)) {
                            selectedSeconds = seconds
                        }
                        .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
                        .foregroundStyle(selectedSeconds == seconds ? Color.white : Theme.Color.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            selectedSeconds == seconds ? Theme.Color.accent : Theme.Color.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                }

                Stepper("每次调整 15 秒", value: $selectedSeconds, in: 30...300, step: 15)
                    .font(.subheadline)

                VStack(spacing: Theme.Spacing.s) {
                    Button("仅本次训练") {
                        onUseToday(selectedSeconds)
                        dismiss()
                    }
                    .buttonStyle(.primaryCTA)

                    if canSaveToPlan {
                        Button("保存到训练计划") {
                            onSaveToPlan(selectedSeconds)
                            dismiss()
                        }
                        .appScaledFont(size: 15, relativeTo: .subheadline, weight: .semibold)
                        .foregroundStyle(Theme.Color.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Theme.Color.background.ignoresSafeArea())
    }

    private func formattedDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func shortDuration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)秒" : "\(seconds / 60)分"
    }
}
