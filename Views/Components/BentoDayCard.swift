//
//  BentoDayCard.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import SwiftUI

struct BentoDayCard: View {
    let dayName: String
    let isRestDay: Bool
    let exerciseCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(dayName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isRestDay {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.purple)
                        Text("休息日")
                            .font(.title3.bold())
                            .foregroundColor(.purple)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(exerciseCount)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("个动作")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
