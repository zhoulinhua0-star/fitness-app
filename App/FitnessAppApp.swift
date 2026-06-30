//
//  FitnessAppApp.swift
//  FitnessApp
//

import SwiftUI
import SwiftData

@main
struct FitnessAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WorkoutDay.self, Exercise.self, WorkoutSession.self, SetLog.self])
    }
}
