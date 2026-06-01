//
//  PlanSetupView.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/29.
//

import SwiftUI
import SwiftData

struct PlanSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutDays: [WorkoutDay]
    
    @State private var isSyncing: Bool = false
    @State private var showSuccessFeedback: Bool = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var sortedDays: [WorkoutDay] {
        let order = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return workoutDays.sorted { (day1, day2) -> Bool in
            let index1 = order.firstIndex(of: day1.dayName) ?? 0
            let index2 = order.firstIndex(of: day2.dayName) ?? 0
            return index1 < index2
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    if sortedDays.isEmpty {
                        ProgressView("正在初始化课表...")
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(sortedDays) { day in
                                NavigationLink(destination: DayDetailEditorView(workoutDay: day)) {
                                    LocalBentoDayCard(workoutDay: day)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
                
                calendarSyncButton
            }
            .navigationTitle("健身课表")
            .background(Color(.systemGroupedBackground))
            .onAppear {
                initializeDefaultDataIfNeeded()
            }
        }
    }
}

// MARK: - 🧱 带有热力进度条的内嵌便当盒
struct LocalBentoDayCard: View {
    let workoutDay: WorkoutDay
    
    // 自动计算今日总组数
    var totalSets: Int {
        workoutDay.exercises.reduce(0) { $0 + $1.sets }
    }
    
    // 根据组数计算颜色
    var intensityColor: Color {
        if totalSets < 12 { return .blue }
        else if totalSets <= 20 { return .orange }
        else { return .red }
    }
    
    // 根据组数计算文案
    var intensityText: String {
        if totalSets < 12 { return "适中" }
        else if totalSets <= 20 { return "高燃" }
        else { return "极限" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workoutDay.dayName)
                    .font(.title3)
                    .bold()
                Spacer()
                if workoutDay.isRestDay {
                    Text("休息")
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
            }
            
            Divider()
            
            if workoutDay.isRestDay {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "battery.100")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text("充电恢复中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workoutDay.exercises.isEmpty {
                VStack {
                    Spacer()
                    Text("无训练安排")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("点击去添加")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // 显示前两三个动作
                    ForEach(workoutDay.exercises.sorted(by: { $0.order < $1.order }).prefix(2)) { exercise in
                        HStack {
                            Text("• \(exercise.name)")
                                .font(.footnote)
                                .lineLimit(1)
                            Spacer()
                            Text("\(exercise.sets)组")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    if workoutDay.exercises.count > 2 {
                        Text("等共 \(workoutDay.exercises.count) 个动作...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    
                    Spacer()
                    
                    // 🔥 新增：强度热力条与统计
                    VStack(spacing: 4) {
                        HStack {
                            Text("🔥 强度: \(intensityText)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(intensityColor)
                            Spacer()
                            Text("\(totalSets) 组")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: min(Double(totalSets) / 25.0, 1.0))
                            .progressViewStyle(.linear)
                            .tint(intensityColor)
                    }
                }
            }
        }
        .padding()
        .frame(height: 155) // 稍微拉高一点以容纳进度条
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - ⚙️ 逻辑与同步按钮扩展
extension PlanSetupView {
    private var calendarSyncButton: some View {
        VStack {
            Button(action: syncToCalendar) {
                HStack(spacing: 10) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Syncing to Calendar...")
                            .font(.headline)
                            .bold()
                    } else if showSuccessFeedback {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                            .transition(.scale.combined(with: .opacity))
                        Text("Sync Successfully!")
                            .font(.headline)
                            .bold()
                    } else {
                        Image(systemName: "calendar.badge.plus")
                            .font(.headline)
                        Text("Sync to Calendar")
                            .font(.headline)
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSyncing ? Color.gray : (showSuccessFeedback ? Color.green : Color(.systemBlue)))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isSyncing || showSuccessFeedback)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    private func syncToCalendar() {
        isSyncing = true
        Task {
            let success = await CalendarManager.shared.requestAccessAndSync(workoutDays: sortedDays)
            await MainActor.run {
                isSyncing = false
                
                if success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showSuccessFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSuccessFeedback = false
                        }
                    }
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }
    }
    
    private func initializeDefaultDataIfNeeded() {
        if workoutDays.isEmpty {
            let daysOrder = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
            for dayName in daysOrder {
                let newDay = WorkoutDay(dayName: dayName, isRestDay: dayName == "周日")
                modelContext.insert(newDay)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - 🗂️ 独立页面：含统计与复制功能
struct DayDetailEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutDay: WorkoutDay
    
    // 引入所有天数，为了实现“一键复制”功能
    @Query private var allDays: [WorkoutDay]
    
    @State private var newExerciseName = ""
    @State private var newSets = 4
    @State private var newReps = 12
    
    // 实时计算总容量
    var totalSets: Int {
        workoutDay.exercises.reduce(0) { $0 + $1.sets }
    }
    
    // 过滤出其他有动作的日期（用于一键复制）
    var copyableDays: [WorkoutDay] {
        let order = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return allDays
            .filter { $0.dayName != workoutDay.dayName && !$0.isRestDay && !$0.exercises.isEmpty }
            .sorted { (d1, d2) -> Bool in
                let i1 = order.firstIndex(of: d1.dayName) ?? 0
                let i2 = order.firstIndex(of: d2.dayName) ?? 0
                return i1 < i2
            }
    }
    
    var body: some View {
        List {
            Section(header: Text("状态设置")) {
                Toggle("🗓️ 将今天设为休息日", isOn: $workoutDay.isRestDay)
                    .tint(.green)
            }
            
            if !workoutDay.isRestDay {
                // 动态显示总组数
                Section(header: Text("💪 已编排动作 (今日总容量: \(totalSets) 组)")) {
                    if workoutDay.exercises.isEmpty {
                        // 如果为空且有其他日期可复制，展示快捷复制功能
                        if !copyableDays.isEmpty {
                            Menu {
                                ForEach(copyableDays) { sourceDay in
                                    Button("复制 \(sourceDay.dayName) 的课表") {
                                        copyExercises(from: sourceDay)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("一键复制其他日期的课表...")
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text("暂无动作，请在下方添加")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(workoutDay.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                            ExerciseInlineEditorRow(exercise: exercise)
                        }
                        .onDelete(perform: deleteExercise)
                        .onMove(perform: moveExercise)
                    }
                }
                
                Section(header: Text("➕ 快速添加新动作")) {
                    TextField("输入动作名称 (如: 卧推、深蹲)", text: $newExerciseName)
                    Stepper("🎯 训练组数:  \(newSets) 组", value: $newSets, in: 1...10)
                    Stepper("🔄 每组次数:  \(newReps) 次", value: $newReps, in: 1...99)
                    
                    Button(action: addExercise) {
                        Text("确认添加")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle("\(workoutDay.dayName) 安排")
        .navigationBarTitleDisplayMode(.inline)
        // 🔥 新增：清空按钮菜单
        .toolbar {
            if !workoutDay.isRestDay && !workoutDay.exercises.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: clearAllExercises) {
                            Label("清空今日动作", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func addExercise() {
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let currentMaxOrder = workoutDay.exercises.count
        let exercise = Exercise(name: trimmedName, sets: newSets, reps: newReps, order: currentMaxOrder)
        
        withAnimation {
            workoutDay.exercises.append(exercise)
        }
        newExerciseName = ""
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        let sortedList = workoutDay.exercises.sorted(by: { $0.order < $1.order })
        for index in offsets {
            workoutDay.exercises.removeAll { $0.id == sortedList[index].id }
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        var sortedList = workoutDay.exercises.sorted(by: { $0.order < $1.order })
        sortedList.move(fromOffsets: source, toOffset: destination)
        
        for index in 0..<sortedList.count {
            sortedList[index].order = index
        }
    }
    
    // 一键复制逻辑
    private func copyExercises(from sourceDay: WorkoutDay) {
        let sortedSource = sourceDay.exercises.sorted(by: { $0.order < $1.order })
        withAnimation {
            for (index, exercise) in sortedSource.enumerated() {
                // 创建全新的对象存入数据库，防止引用冲突
                let newExercise = Exercise(name: exercise.name, sets: exercise.sets, reps: exercise.reps, order: index)
                workoutDay.exercises.append(newExercise)
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // 一键清空逻辑
    private func clearAllExercises() {
        withAnimation {
            workoutDay.exercises.removeAll()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - ✏️ 真正的所见即所得行内编辑器行
struct ExerciseInlineEditorRow: View {
    @Bindable var exercise: Exercise
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("动作名称", text: $exercise.name)
                .font(.headline)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Stepper(value: $exercise.sets, in: 1...20) {
                    Text("组数: \(exercise.sets)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Stepper(value: $exercise.reps, in: 1...100) {
                    Text("次数: \(exercise.reps)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
