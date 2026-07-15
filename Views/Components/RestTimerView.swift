//
//  RestTimerView.swift
//  FitnessApp
//

import SwiftUI

struct RestTimerView: View {
    enum Phase { case running, finished }

    @Binding var endDate: Date
    let onSkip: () -> Void
    let onComplete: () -> Void
    let onEndDateChanged: (Date) -> Void

    @State private var phase: Phase = .running
    @State private var didFireCompletionHaptic = false

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
            VStack(spacing: Theme.Spacing.s) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(Theme.Color.accent)
                    Text("休息 \(formattedTime(remaining))")
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Button("跳过") {
                        NotificationManager.cancelRestEndNotification()
                        onSkip()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(minWidth: 44, minHeight: 44)
                }

                HStack(spacing: Theme.Spacing.s) {
                    adjustmentButton(title: "−15 秒", delta: -15)
                    adjustmentButton(title: "+15 秒", delta: 15)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Color.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .onChange(of: remaining) { _, newValue in
                guard newValue <= 0, phase == .running else { return }
                handleRestFinished()
            }
        }
    }

    private func adjustmentButton(title: String, delta: TimeInterval) -> some View {
        Button(title) {
            let adjustedEndDate = max(endDate.addingTimeInterval(delta), Date().addingTimeInterval(1))
            endDate = adjustedEndDate
            onEndDateChanged(adjustedEndDate)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.Color.accent)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Theme.Color.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("休息计时\(title)")
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
