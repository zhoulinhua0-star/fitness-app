//
//  RingProgressView.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import SwiftUI

struct RingProgressView: View {
    var progress: Double
    var size: CGFloat = 60
    var lineWidth: CGFloat = 8
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.23, weight: .bold))
        }
        .frame(width: size, height: size)
    }
}
