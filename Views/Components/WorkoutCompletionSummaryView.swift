import SwiftUI

struct WorkoutCompletionSummaryView: View {
    let completedSets: Int
    let totalSets: Int
    let completedExercises: Int
    let totalExercises: Int
    let duration: TimeInterval
    let onDismiss: () -> Void
    
    @State private var didDismiss = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor.gradient)
                    .symbolEffect(.bounce, value: completedSets)
                
                Text("今日训练完成")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                VStack(spacing: 12) {
                    summaryRow(title: "完成组数", value: "\(completedSets) / \(totalSets) 组")
                    summaryRow(title: "完成动作", value: "\(completedExercises) / \(totalExercises) 个")
                    summaryRow(title: "训练时长", value: formattedDuration(duration))
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .padding(24)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 16, y: 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .onTapGesture { dismissOnce() }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    dismissOnce()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.35).ignoresSafeArea())
        .onTapGesture { dismissOnce() }
    }
    
    private func dismissOnce() {
        guard !didDismiss else { return }
        didDismiss = true
        onDismiss()
    }
    
    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
    
    private func formattedDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes) 分 \(seconds) 秒"
        }
        return "\(seconds) 秒"
    }
}
