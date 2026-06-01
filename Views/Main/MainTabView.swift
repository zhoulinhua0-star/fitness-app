//
//  MainTabView.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // 标签 1：今日打卡
            TodayWorkoutView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("今日")
                }
            
            // 标签 2：图表统计 (新加入！)
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("统计")
                }
            
            // 标签 3：计划设置
            PlanSetupView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("计划")
                }
        }
        .tint(.accentColor) // 完美联动你刚才在 Assets 设定的活力主题色！
    }
}

#Preview {
    MainTabView()
}
