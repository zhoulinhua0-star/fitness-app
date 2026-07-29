//
//  MainTabView.swift
//  FitnessApp
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var navigation = AppNavigation.shared

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            TodayWorkoutView()
                .tabItem {
                    Label("今日", systemImage: "dumbbell.fill")
                }
                .tag(AppTab.today)

            AnalyticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.analytics)

            PlanSetupView(onSwitchToToday: { navigation.selectedTab = .today })
                .tabItem {
                    Label("计划", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(AppTab.plan)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(Theme.Color.accent)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [WorkoutDay.self, Exercise.self, WorkoutSession.self, SetLog.self, CardioLog.self], inMemory: true)
}
