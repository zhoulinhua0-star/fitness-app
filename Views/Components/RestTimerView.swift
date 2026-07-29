import SwiftUI

struct RestTimerView: View {
    let endDate: Date
    let nextSetNumber: Int
    let onSkip: () -> Void
    let onEndDateChanged: (Date) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = endDate.timeIntervalSince(context.date)
            if remaining > 0 {
                countdownContent(remaining: remaining)
            } else {
                RestReadyView(nextSetNumber: nextSetNumber, wasSkipped: false)
            }
        }
    }

    private func countdownContent(remaining: TimeInterval) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.Color.accent)
                Text("休息 \(formattedTime(remaining))")
                    .appScaledFont(size: 14, relativeTo: .subheadline, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Color.textPrimary)
                Spacer()
                Button("跳过", action: onSkip)
                    .appScaledFont(size: 14, relativeTo: .subheadline, weight: .semibold)
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
    }

    private func adjustmentButton(title: String, delta: TimeInterval) -> some View {
        Button(title) {
            onEndDateChanged(max(endDate.addingTimeInterval(delta), Date().addingTimeInterval(1)))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
        .foregroundStyle(Theme.Color.accent)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Theme.Color.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("休息计时\(title)")
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let total = max(1, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct RestTimerBadge: View {
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = endDate.timeIntervalSince(context.date)
            if remaining > 0 {
                Label(formattedTime(remaining), systemImage: "timer")
                    .appScaledFont(size: 12, relativeTo: .caption, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 32)
                    .background(Theme.Color.accentSoft, in: Capsule())
                    .accessibilityLabel("剩余休息时间 \(formattedTime(remaining))")
            } else {
                RestReadyBadge()
            }
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let total = max(1, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct RestReadyView: View {
    let nextSetNumber: Int
    let wasSkipped: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Color.success)

            VStack(alignment: .leading, spacing: 2) {
                Text(wasSkipped ? "已跳过休息" : "休息完成")
                    .appScaledFont(size: 14, relativeTo: .subheadline, weight: .semibold)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("可以开始第 \(nextSetNumber) 组")
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.s)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Color.tintMint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct RestReadyBadge: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Color.success)
            Text("可开始")
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .appScaledFont(size: 12, relativeTo: .caption, weight: .semibold)
        .padding(.horizontal, 9)
        .frame(minHeight: 32)
        .background(Theme.Color.tintMint, in: Capsule())
        .accessibilityLabel("休息完成，可以开始下一组")
    }
}
