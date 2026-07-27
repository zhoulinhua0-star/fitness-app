//
//  FitnessAppApp.swift
//  FitnessApp
//

import SwiftUI
import SwiftData

@main
struct FitnessAppApp: App {
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var notificationDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WorkoutDay.self, Exercise.self, WorkoutSession.self, SetLog.self,
                              WorkoutTemplate.self, TemplateExercise.self])
    }
}
