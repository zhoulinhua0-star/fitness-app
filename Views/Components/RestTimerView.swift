import SwiftUI

struct RestTimerView: View {
    let endDate: Date
    let onSkip: () -> Void
    let onEndDateChanged: (Date) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
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
        let total = Int(interval.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct RestTimerBadge: View {
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            Label(formattedTime(remaining), systemImage: "timer")
                .appScaledFont(size: 12, relativeTo: .caption, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(Theme.Color.accent)
                .padding(.horizontal, 9)
                .frame(minHeight: 32)
                .background(Theme.Color.accentSoft, in: Capsule())
                .accessibilityLabel("剩余休息时间 \(formattedTime(remaining))")
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
