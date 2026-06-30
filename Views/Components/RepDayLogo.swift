//
//  RepDayLogo.swift
//  FitnessApp
//
//  The app's dumbbell icon, restyled from the original orange-on-navy artwork
//  into clean lavender line-art that matches the Tiimo aesthetic. Fully vector,
//  so it stays crisp at any size on the splash screen.
//

import SwiftUI

/// A dumbbell drawn as a single stroked path: center bar + two weight stacks.
struct DumbbellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let midY = rect.midY

        // Center connecting bar.
        let barHeight = h * 0.16
        p.addRoundedRect(
            in: CGRect(x: w * 0.32, y: midY - barHeight / 2, width: w * 0.36, height: barHeight),
            cornerSize: CGSize(width: barHeight / 2, height: barHeight / 2)
        )

        // Inner weight plates (taller).
        let innerH = h * 0.5
        let innerW = w * 0.1
        p.addRoundedRect(
            in: CGRect(x: w * 0.24, y: midY - innerH / 2, width: innerW, height: innerH),
            cornerSize: CGSize(width: 6, height: 6)
        )
        p.addRoundedRect(
            in: CGRect(x: w * 0.66, y: midY - innerH / 2, width: innerW, height: innerH),
            cornerSize: CGSize(width: 6, height: 6)
        )

        // Outer weight plates (shorter) + end caps.
        let outerH = h * 0.34
        let outerW = w * 0.08
        p.addRoundedRect(
            in: CGRect(x: w * 0.14, y: midY - outerH / 2, width: outerW, height: outerH),
            cornerSize: CGSize(width: 5, height: 5)
        )
        p.addRoundedRect(
            in: CGRect(x: w * 0.78, y: midY - outerH / 2, width: outerW, height: outerH),
            cornerSize: CGSize(width: 5, height: 5)
        )

        // End caps.
        let capH = h * 0.14
        let capW = w * 0.05
        p.addRoundedRect(
            in: CGRect(x: w * 0.08, y: midY - capH / 2, width: capW, height: capH),
            cornerSize: CGSize(width: 3, height: 3)
        )
        p.addRoundedRect(
            in: CGRect(x: w * 0.87, y: midY - capH / 2, width: capW, height: capH),
            cornerSize: CGSize(width: 3, height: 3)
        )

        return p
    }
}

/// The full brand mark: dumbbell inside a soft circle, à la Tiimo's logo.
struct RepDayLogo: View {
    var size: CGFloat = 120
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Color.textPrimary, lineWidth: lineWidth)

            DumbbellShape()
                .stroke(
                    Theme.Color.accent,
                    style: StrokeStyle(lineWidth: lineWidth * 0.8, lineJoin: .round)
                )
                .frame(width: size * 0.62, height: size * 0.62)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 40) {
        RepDayLogo(size: 140)
        RepDayLogo(size: 80, lineWidth: 4)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Color.background)
}
