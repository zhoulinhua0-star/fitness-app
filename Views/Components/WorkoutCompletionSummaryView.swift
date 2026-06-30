//
//  WorkoutCompletionSummaryView.swift
//  FitnessApp
//

import SwiftUI

struct WorkoutCompletionSummaryView: View {
    let completedSets: Int
    let totalSets: Int
    let completedExercises: Int
    let totalExercises: Int
    let onDismiss: () -> Void

    @State private var didDismiss = false

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: Theme.Spacing.xl) {
                Text("🏆")
                    .font(.system(size: 56))
                    .symbolEffect(.bounce, value: completedSets)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("今日训练完成")
                        .font(.displayMedium)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("出色完成！继续保持")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                VStack(spacing: Theme.Spacing.s) {
                    summaryRow(label: "完成组数", value: "\(completedSets) / \(totalSets) 组")
                    Divider().background(Theme.Color.hairline)
                    summaryRow(label: "完成动作", value: "\(completedExercises) / \(totalExercises) 个")
                }
                .padding(Theme.Spacing.l)
                .background(Theme.Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))

                Button("关闭", action: dismissOnce)
                    .buttonStyle(.primaryCTA)
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Theme.Shadow.color, radius: 30, x: 0, y: 10)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, 40)
            .onTapGesture { dismissOnce() }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { dismissOnce() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4).ignoresSafeArea())
        .onTapGesture { dismissOnce() }
    }

    private func dismissOnce() {
        guard !didDismiss else { return }
        didDismiss = true
        onDismiss()
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
        }
    }
}
