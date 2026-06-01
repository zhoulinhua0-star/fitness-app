//
//  FitnessAppApp.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/27.
//

import SwiftUI
import SwiftData

@main
struct FitnessAppApp: App {
    var body: some Scene {
        WindowGroup {
            // 这里原来是 PlanSetupView()，现在替换为导航容器
            MainTabView()
        }
        // 数据库总电源保持不变
        .modelContainer(for: [WorkoutDay.self, Exercise.self])
    }
}
