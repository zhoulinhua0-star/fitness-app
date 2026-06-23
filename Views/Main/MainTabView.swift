//
//  MainTabView.swift
//  FitnessApp
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayWorkoutView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("今日")
                }
            
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("统计")
                }
            
            PlanSetupView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("计划")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
        }
        .tint(.accentColor)
    }
}

#Preview {
    MainTabView()
}
