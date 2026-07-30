//
//  WorkoutCompletionSummaryView.swift
//  FitnessApp
//

import SwiftUI

struct WorkoutCompletionSummaryView: View {
    let completedSets: Int
    let totalSets: Int
    let completedCardio: Int
    let totalCardio: Int
    let cardioDurationSeconds: Int
    let completedExercises: Int
    let totalExercises: Int
    let onDismiss: () -> Void

    @Environment(\.locale) private var locale
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
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                VStack(spacing: Theme.Spacing.s) {
                    if totalSets > 0 {
                        summaryRow(
                            label: "完成组数",
                            value: AppLocalization.format(
                                "%lld / %lld 组",
                                languageIdentifier: locale.identifier,
                                completedSets,
                                totalSets
                            )
                        )
                        Divider().background(Theme.Color.hairline)
                    }
                    if totalCardio > 0 {
                        summaryRow(
                            label: "完成有氧",
                            value: AppLocalization.format(
                                "%lld / %lld 项 · %lld 分钟",
                                languageIdentifier: locale.identifier,
                                completedCardio,
                                totalCardio,
                                cardioDurationSeconds / 60
                            )
                        )
                        Divider().background(Theme.Color.hairline)
                    }
                    summaryRow(
                        label: "完成动作",
                        value: AppLocalization.format(
                            "%lld / %lld 个",
                            languageIdentifier: locale.identifier,
                            completedExercises,
                            totalExercises
                        )
                    )
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
            Text(
                AppLocalization.string(
                    label,
                    languageIdentifier: locale.identifier
                )
            )
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)
        }
    }
}
