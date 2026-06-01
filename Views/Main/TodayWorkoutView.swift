//
//  TodayWorkoutView.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import SwiftUI
import SwiftData

struct TodayWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutDays: [WorkoutDay]
    
    // 💡 废弃了内存级 @State 变量，现在直接读取数据库的日期！
    
    // 智能获取今天的课表
    var todayPlan: WorkoutDay? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        let todayString = formatter.string(from: Date()).replacingOccurrences(of: "星期", with: "周")
        return workoutDays.first(where: { $0.dayName == todayString })
    }
    
    // 动态计算已完成数量（只要最后打卡日期是“今天”，就算完成）
    var completedCount: Int {
        guard let plan = todayPlan else { return 0 }
        return plan.exercises.filter { isCompletedToday($0) }.count
    }
    
    // 计算当前进度比例 (0.0 到 1.0)
    var progress: Double {
        guard let plan = todayPlan, !plan.exercises.isEmpty else { return 0 }
        return Double(completedCount) / Double(plan.exercises.count)
    }
    
    // 💡 核心逻辑：判断某个动作是不是“今天”完成的
    private func isCompletedToday(_ exercise: Exercise) -> Bool {
        guard let date = exercise.lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if let plan = todayPlan {
                    if plan.isRestDay {
                        restDayView
                    } else if plan.exercises.isEmpty {
                        emptyPlanView
                    } else {
                        workoutListView(plan: plan)
                    }
                } else {
                    Text("未找到计划").foregroundColor(.secondary)
                }
            }
            .navigationTitle("今日打卡")
        }
    }
}

// MARK: - 核心子视图拆解
extension TodayWorkoutView {
    
    private func workoutListView(plan: WorkoutDay) -> some View {
        VStack(spacing: 10) {
            progressHeader(plan: plan)
                .padding(.top)
            
            List {
                ForEach(plan.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                    exerciseRow(exercise)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }
                .onMove { source, destination in
                    moveExerciseInToday(plan: plan, from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal)
        }
    }
    
    private func moveExerciseInToday(plan: WorkoutDay, from source: IndexSet, to destination: Int) {
        var sortedList = plan.exercises.sorted(by: { $0.order < $1.order })
        sortedList.move(fromOffsets: source, toOffset: destination)
        
        for index in 0..<sortedList.count {
            sortedList[index].order = index
        }
        
        try? modelContext.save()
    }
    
    // 顶部进度看板
    private func progressHeader(plan: WorkoutDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("训练进度")
                    .font(.headline)
                Text("\(completedCount) / \(plan.exercises.count) 个动作")
                    .font(.title2.bold())
                    .foregroundColor(.accentColor)
            }
            Spacer()
            
            RingProgressView(progress: progress, size: 60)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // 单个动作打卡行
    private func exerciseRow(_ exercise: Exercise) -> some View {
        let isCompleted = isCompletedToday(exercise)
        
        return Button(action: { toggleExercise(exercise) }) {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .accentColor : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .strikethrough(isCompleted, color: .secondary)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                    
                    Text("\(exercise.sets) 组 × \(exercise.reps) 次")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 💡 打卡状态切换逻辑升级：直接写入数据库！
    private func toggleExercise(_ exercise: Exercise) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation {
            if isCompletedToday(exercise) {
                // 如果今天已经打卡了，取消打卡（抹去记录）
                exercise.lastCompletedDate = nil
            } else {
                // 如果没打卡，记录为此时此刻
                exercise.lastCompletedDate = Date()
                
                // 检查是否全做完了
                if completedCount == todayPlan?.exercises.count {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
        // 直接落地保存，就算此时杀掉 App 数据也绝不会丢！
        try? modelContext.save()
    }
    
    // 休息日视图
    private var restDayView: some View {
        VStack(spacing: 20) {
            Image(systemName: "battery.100")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .symbolEffect(.pulse)
            Text("今天是休息日")
                .font(.title2.bold())
            Text("肌肉正在修复，好好放松一下吧！")
                .foregroundColor(.secondary)
        }
    }
    
    // 计划为空视图
    private var emptyPlanView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("今日无训练安排")
                .font(.title2.bold())
            Text("去「计划」页面添加一些动作吧")
                .foregroundColor(.secondary)
        }
    }
}
