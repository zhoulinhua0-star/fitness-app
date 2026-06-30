//
//  RestTimerView.swift
//  FitnessApp
//

import SwiftUI

struct RestTimerView: View {
    enum Phase { case running, finished }

    let durationSeconds: Int
    let onSkip: () -> Void
    let onComplete: () -> Void

    @State private var endDate: Date
    @State private var phase: Phase = .running
    @State private var didFireCompletionHaptic = false

    init(durationSeconds: Int, onSkip: @escaping () -> Void, onComplete: @escaping () -> Void) {
        self.durationSeconds = durationSeconds
        self.onSkip = onSkip
        self.onComplete = onComplete
        _endDate = State(initialValue: Date().addingTimeInterval(TimeInterval(durationSeconds)))
    }

    var body: some View {
        Group {
            switch phase {
            case .running: runningView
            case .finished: finishedView
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: phase)
    }

    private var runningView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.Color.accent)
                Text("休息 \(formattedTime(remaining))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                Spacer()
                Button("跳过") {
                    NotificationManager.cancelRestEndNotification()
                    onSkip()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s + 2)
            .background(Theme.Color.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .onChange(of: remaining) { _, newValue in
                guard newValue <= 0, phase == .running else { return }
                handleRestFinished()
            }
        }
    }

    private var finishedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Color.success)
            Text("休息完成 · 开始下一组")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s + 2)
        .background(Theme.Color.tintMint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { onComplete() }
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
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
