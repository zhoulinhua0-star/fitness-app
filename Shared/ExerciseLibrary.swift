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
    static let definitions: [ExerciseDefinition] = [
        strength("barbell-bench-press", "杠铃卧推", .chest, .benchPress),
        strength("dumbbell-bench-press", "哑铃卧推", .chest, .benchPress),
        strength("incline-bench-press", "上斜卧推", .chest, .benchPress),
        strength("machine-fly", "器械夹胸", .chest),
        strength("dumbbell-fly", "哑铃飞鸟", .chest),
        strength("cable-fly", "绳索夹胸", .chest),
        strength("push-up", "俯卧撑", .chest, .pushUp),

        strength("pull-up", "引体向上", .back, .pullUp),
        strength("barbell-row", "杠铃划船", .back, .strengthRow),
        strength("one-arm-dumbbell-row", "单臂哑铃划船", .back, .strengthRow),
        strength("seated-cable-row", "坐姿绳索划船", .back, .strengthRow),
        strength("lat-pulldown", "高位下拉", .back, .pullUp),
        strength("deadlift", "硬拉", .back, .deadlift),
        strength("t-bar-row", "T杠划船", .back, .strengthRow),

        strength("squat", "深蹲", .legs, .squat),
        strength("leg-press", "腿举", .legs),
        strength("leg-curl", "腿弯举", .legs),
        strength("leg-extension", "腿伸展", .legs),
        strength("bulgarian-split-squat", "保加利亚深蹲", .legs, .lunge),
        strength("lunge", "弓步蹲", .legs, .lunge),
        strength("calf-raise", "小腿提踵", .legs),

        strength("overhead-press", "肩上推举", .shoulders, .overheadPress),
        strength("lateral-raise", "哑铃侧平举", .shoulders),
        strength("front-raise", "前平举", .shoulders),
        strength("reverse-fly", "俯身飞鸟", .shoulders),
        strength("face-pull", "面拉", .shoulders),
        strength("arnold-press", "阿诺德推举", .shoulders, .overheadPress),

        strength("biceps-curl", "二头弯举", .arms, .curl),
        strength("hammer-curl", "锤式弯举", .arms, .curl),
        strength("triceps-pushdown", "绳索下压", .arms, .triceps),
        strength("skull-crusher", "颅骨破碎者", .arms, .triceps),
        strength("dumbbell-curl", "哑铃弯举", .arms, .curl),
        strength("close-grip-bench-press", "窄距卧推", .arms, .benchPress),

        strength("crunch", "卷腹", .core),
        strength("plank", "平板支撑", .core, .plank),
        strength("russian-twist", "俄罗斯转体", .core),
        strength("hanging-leg-raise", "悬挂举腿", .core),
        strength("weighted-crunch", "负重卷腹", .core),
        strength("side-plank", "侧平板", .core, .plank),

        cardio("treadmill", "跑步机", "figure.run.treadmill", 20, .running),
        cardio("outdoor-run", "户外跑步", "figure.run", 30, .running),
        cardio("stationary-bike", "动感单车", "figure.indoor.cycle", 30, .cycling),
        cardio("outdoor-cycling", "户外骑行", "figure.outdoor.cycle", 45, .cycling),
        cardio("elliptical", "椭圆机", "figure.elliptical", 20),
        cardio("rowing-machine", "划船机", "figure.rower", 20, .cardioRow),
        cardio("stair-climber", "爬楼机", "figure.stair.stepper", 20),
        cardio("jump-rope", "跳绳", "figure.jumprope", 15, .jumpRope),
        cardio("aerobics", "有氧操", "figure.dance", 30)
    ]

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
              exercises: ["卷腹", "平板支撑", "俄罗斯转体", "悬挂举腿", "负重卷腹", "侧平板"]),

        .init(id: "cardio",
              name: "有氧", emoji: "🏃",
              tint: Theme.Color.tintMint,
              exercises: definitions.filter { $0.activityType == .cardio }.map(\.name))
    ]

    static func definition(named name: String) -> ExerciseDefinition? {
        definitions.first {
            $0.name == name ||
                $0.localizedName(languageIdentifier: "zh-Hans")
                    .localizedCaseInsensitiveCompare(name) == .orderedSame ||
                $0.localizedName(languageIdentifier: "en")
                    .localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    static func displayName(for storedName: String) -> String {
        definition(named: storedName)?.localizedName ?? storedName
    }

    static func displayName(
        for storedName: String,
        languageIdentifier: String
    ) -> String {
        definition(named: storedName)?
            .localizedName(languageIdentifier: languageIdentifier) ?? storedName
    }

    private static func strength(
        _ id: String,
        _ name: String,
        _ bodyPart: ExerciseBodyPart,
        _ poseIcon: ExercisePoseIcon? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            bodyPart: bodyPart,
            systemImage: bodyPart.systemImage,
            poseIcon: poseIcon
        )
    }

    private static func cardio(
        _ id: String,
        _ name: String,
        _ systemImage: String,
        _ defaultMinutes: Int,
        _ poseIcon: ExercisePoseIcon? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            activityType: .cardio,
            trackingMode: .duration,
            systemImage: systemImage,
            poseIcon: poseIcon,
            defaultDurationSeconds: defaultMinutes * 60
        )
    }
}

// MARK: - ImprovEntry  (staging value type used by the improv builder)

struct ImprovEntry: Identifiable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var completedSets: Int
    var activityType: ExerciseActivityType
    var trackingMode: ExerciseTrackingMode
    var targetDurationSeconds: Int
    let groupTint: Color
    /// True when the user typed this lift by hand rather than picking it from
    /// the library — used to render it in the dedicated "自定义动作" list.
    let isCustom: Bool

    init(
        name: String,
        sets: Int = 3,
        reps: Int = 10,
        activityType: ExerciseActivityType = .strength,
        trackingMode: ExerciseTrackingMode = .setsAndReps,
        targetDurationSeconds: Int = 20 * 60,
        groupTint: Color = Theme.Color.accentSoft,
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.completedSets = 0
        self.activityType = activityType
        self.trackingMode = trackingMode
        self.targetDurationSeconds = targetDurationSeconds
        self.groupTint = groupTint
        self.isCustom = isCustom
    }

    var isFullyDone: Bool { completedSets >= sets }
    var progress: Double { sets > 0 ? Double(completedSets) / Double(sets) : 0 }
}
