//
//  RootView.swift
//  FitnessApp
//
//  Hosts the launch sequence: SplashView sits on top of MainTabView and, once
//  finished, slides/fades up to reveal the main content. Because `showSplash`
//  flips to false, the splash leaves the view hierarchy and is freed.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainTabView()

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSplash = false
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [WorkoutDay.self, Exercise.self, WorkoutSession.self, SetLog.self], inMemory: true)
}
