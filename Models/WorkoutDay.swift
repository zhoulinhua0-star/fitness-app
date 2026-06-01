//
//  Untitled.swift
//  FitnessApp
//
//  Created by 周琳桦 on 2026/5/28.
//

import Foundation
import SwiftData

@Model
final class WorkoutDay {
    var dayName: String
    var isRestDay: Bool
    
    // 建立级联删除关系（极其重要）
    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise]
    
    init(dayName: String, isRestDay: Bool = false, exercises: [Exercise] = []) {
        self.dayName = dayName
        self.isRestDay = isRestDay
        self.exercises = exercises
    }
}
