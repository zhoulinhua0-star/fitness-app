//
//  ExerciseLibrary.swift
//  FitnessApp
//
//  Static exercise library organised by muscle group, plus the ImprovEntry
//  value type the improv builder uses to stage a workout before injecting it
//  into today's logging surface.
//

import SwiftUI

// MARK: - Muscle group data

struct MuscleGroupData: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let tint: Color
    let exercises: [String]

    static func == (lhs: MuscleGroupData, rhs: MuscleGroupData) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ExerciseLibrary {
    static let groups: [MuscleGroupData] = [
        .init(id: "chest",
              name: "胸部", emoji: "🏋️",
              tint: Theme.Color.tintPeach,
              exercises: ["杠铃卧推", "哑铃卧推", "上斜卧推", "器械夹胸", "哑铃飞鸟", "绳索夹胸", "俯卧撑"]),

        .init(id: "back",
              name: "背部", emoji: "🪝",
              tint: Theme.Color.tintBlue,
              exercises: ["引体向上", "杠铃划船", "单臂哑铃划船", "坐姿绳索划船", "高位下拉", "硬拉", "T杠划船"]),

        .init(id: "legs",
              name: "腿部", emoji: "🦵",
              tint: Theme.Color.tintMint,
              exercises: ["深蹲", "腿举", "腿弯举", "腿伸展", "保加利亚深蹲", "弓步蹲", "小腿提踵"]),

        .init(id: "shoulders",
              name: "肩部", emoji: "🤸",
              tint: Theme.Color.tintPurple,
              exercises: ["肩上推举", "哑铃侧平举", "前平举", "俯身飞鸟", "面拉", "阿诺德推举"]),

        .init(id: "arms",
              name: "手臂", emoji: "💪",
              tint: Theme.Color.accentSoft,
              exercises: ["二头弯举", "锤式弯举", "绳索下压", "颅骨破碎者", "哑铃弯举", "窄距卧推"]),

        .init(id: "core",
              name: "核心", emoji: "🔥",
              tint: Theme.Color.tintOrange,
              exercises: ["卷腹", "平板支撑", "俄罗斯转体", "悬挂举腿", "负重卷腹", "侧平板"])
    ]
}

// MARK: - ImprovEntry  (staging value type used by the improv builder)

struct ImprovEntry: Identifiable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var completedSets: Int
    let groupTint: Color

    init(name: String, sets: Int = 3, reps: Int = 10, groupTint: Color = Theme.Color.accentSoft) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.completedSets = 0
        self.groupTint = groupTint
    }

    var isFullyDone: Bool { completedSets >= sets }
    var progress: Double { sets > 0 ? Double(completedSets) / Double(sets) : 0 }
}
