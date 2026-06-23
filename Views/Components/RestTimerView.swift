import SwiftUI

struct RestTimerView: View {
    enum Phase {
        case running
        case finished
    }
    
    let durationSeconds: Int
    let onSkip: () -> Void
    let onComplete: () -> Void
    
    @State private var endDate: Date
    @State private var phase: Phase = .running
    @State private var didFireCompletionHaptic = false
    
    init(
        durationSeconds: Int,
        onSkip: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.durationSeconds = durationSeconds
        self.onSkip = onSkip
        self.onComplete = onComplete
        _endDate = State(initialValue: Date().addingTimeInterval(TimeInterval(durationSeconds)))
    }
    
    var body: some View {
        Group {
            switch phase {
            case .running:
                runningView
            case .finished:
                finishedView
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: phase)
    }
    
    private var runningView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.accentColor)
                Text("休息 \(formattedTime(remaining))")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("跳过") {
                    NotificationManager.cancelRestEndNotification()
                    onSkip()
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.12))
            .cornerRadius(10)
            .onChange(of: remaining) { _, newValue in
                guard newValue <= 0, phase == .running else { return }
                handleRestFinished()
            }
        }
    }
    
    private var finishedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .symbolEffect(.bounce, value: phase)
            Text("休息完成 · 开始下一组")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.12))
        .cornerRadius(10)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onComplete()
            }
        }
    }
    
    private func handleRestFinished() {
        NotificationManager.cancelRestEndNotification()
        
        if !didFireCompletionHaptic {
            didFireCompletionHaptic = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        
        phase = .finished
    }
    
    private func formattedTime(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
