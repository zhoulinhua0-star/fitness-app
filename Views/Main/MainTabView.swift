//
//  MainTabView.swift
//  FitnessApp
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    private enum Tab: Hashable { case today, analytics, plan, profile }
    @State private var selectedTab: Tab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayWorkoutView()
                .tabItem {
                    Label("今日", systemImage: "dumbbell.fill")
                }
                .tag(Tab.today)

            AnalyticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.analytics)

            PlanSetupView(onSwitchToToday: { selectedTab = .today })
                .tabItem {
                    Label("计划", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(Tab.plan)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)
        }
        .tint(Theme.Color.accent)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [WorkoutDay.self, Exercise.self, WorkoutSession.self, SetLog.self], inMemory: true)
}
