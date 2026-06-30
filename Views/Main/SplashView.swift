//
//  SplashView.swift
//  FitnessApp
//
//  Tiimo-style animated launch screen: logo + name + slogan fade/slide in over
//  0.8s, hold, then the whole view is dismissed by RootView after 2.5s.
//

import SwiftUI

struct SplashView: View {
    /// Called once the splash has finished its hold; RootView animates it away.
    let onFinished: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Soft top-to-bottom lavender gradient, like Tiimo's splash.
            LinearGradient(
                colors: [Theme.Color.background, Theme.Color.accentSoft],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                RepDayLogo(size: 132)

                VStack(spacing: Theme.Spacing.s) {
                    Text(Brand.name)
                        .font(.display(40, weight: .bold))
                        .foregroundStyle(Theme.Color.textPrimary)

                    Text(Brand.slogan)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            // Fade-in + slide-up.
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
            // Hold, then hand control back to RootView for the exit transition.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onFinished()
            }
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
