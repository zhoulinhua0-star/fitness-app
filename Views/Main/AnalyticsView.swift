//
//  AnalyticsView.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import SwiftUI
import Charts // 导入苹果官方现代图表框架
import SwiftData

struct AnalyticsView: View {
    @Query private var workoutDays: [WorkoutDay]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // 1. 顶部总览卡片
                    overviewHeader
                    
                    // 2. 核心图表：周训练量分布
                    VStack(alignment: .leading, spacing: 16) {
                        Text("📊 本周计划动作分布")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // 苹果原生高级图表
                        Chart {
                            ForEach(workoutDays) { day in
                                // 柱状图：X轴为星期，Y轴为该天安排的动作数量
                                BarMark(
                                    x: .value("星期", day.dayName),
                                    y: .value("动作数量", day.isRestDay ? 0 : day.exercises.count)
                                )
                                // 给柱状图赋予标志性的渐变主题色
                                .foregroundStyle(Color.accentColor.gradient)
                                .cornerRadius(6) // 柱体圆角
                            }
                        }
                        .frame(height: 200)
                        // 自定义图表刻度
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                    .padding(.horizontal, 20)
                    
                    // 3. 激励名言 Bento 盒子
                    motivationalBox
                }
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("数据统计")
        }
    }
}

// MARK: - 辅助子视图
extension AnalyticsView {
    
    // 总览数据看板
    private var overviewHeader: some View {
        HStack(spacing: 16) {
            let totalWorkouts = workoutDays.filter { !$0.isRestDay && !$0.exercises.isEmpty }.count
            let totalExercises = workoutDays.reduce(0) { $0 + $1.exercises.count }
            
            // 小格子 1：本周练几天
            VStack(alignment: .leading, spacing: 8) {
                Text("训练频次")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(totalWorkouts) 天/周")
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            
            // 小格子 2：总共多少动作
            VStack(alignment: .leading, spacing: 8) {
                Text("总动作数")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(totalExercises) 个")
                    .font(.title2.bold())
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
    
    // 激励卡片
    private var motivationalBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            
            Text("自律不是一种行为，而是一种习惯。你挥洒的每一滴汗水，日历和身体都会帮你记住。")
                .font(.subheadline)
                .italic()
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(for: WorkoutDay.self, inMemory: true)
}
