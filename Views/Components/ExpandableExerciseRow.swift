import SwiftUI
import SwiftData

struct ExpandableExerciseRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise
    let session: WorkoutSession
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSetProgressChanged: () -> Void
    
    @State private var showRestTimer = false
    @State private var restTimerToken = UUID()
    
    private var settings: AppSettings { AppSettings.shared }
    
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
        WorkoutHistoryManager.lastPerformanceSummary(context: modelContext, exerciseName: exercise.name)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerRow
            
            if isExpanded {
                setPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }
    
    private var headerRow: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 12) {
                statusIcon
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                        .strikethrough(isFullyCompleted, color: .secondary)
                        .foregroundColor(isFullyCompleted ? .secondary : .primary)
                    
                    Text("\(completedSets) / \(exercise.sets) 组 · \(exercise.reps) 次/组")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let lastTimeSummary {
                        Text(lastTimeSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: exercise.setProgress)
                        .tint(.accentColor)
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if isFullyCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
        } else {
            RingProgressView(progress: exercise.setProgress, size: 36, lineWidth: 4)
        }
    }
    
    private var setPanel: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.top, 12)
            
            ForEach(setRowIDs, id: \.self) { rowID in
                setRow(setNumber: rowID.setNumber)
            }
            .id(exercise.sets)
            
            if showRestTimer && !isFullyCompleted {
                RestTimerView(
                    durationSeconds: settings.defaultRestSeconds,
                    onSkip: {
                        showRestTimer = false
                    },
                    onComplete: {
                        showRestTimer = false
                    }
                )
                .id(restTimerToken)
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
            
            if state == .next {
                Text("点击完成")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
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
            case .completed, .upcoming: return Color(.tertiarySystemGroupedBackground)
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
            NotificationManager.scheduleRestEndNotification(
                after: settings.defaultRestSeconds,
                exerciseName: exercise.name
            )
            showRestTimer = true
            restTimerToken = UUID()
        }
    }
    
    private func cancelRestTimer() {
        NotificationManager.cancelRestEndNotification()
        showRestTimer = false
    }
    
    private func completeNextSet() {
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
