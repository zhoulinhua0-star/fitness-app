//
//  MainTabView.swift
//  FitnessApp
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayWorkoutView()
                .tabItem {
                    Label("今日", systemImage: "dumbbell.fill")
                }

            AnalyticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }

            PlanSetupView()
                .tabItem {
                    Label("计划", systemImage: "list.bullet.rectangle.portrait.fill")
                }

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(Theme.Color.accent)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [WorkoutDay.self, Exercise.self, WorkoutSession.self, SetLog.self], inMemory: true)
}
