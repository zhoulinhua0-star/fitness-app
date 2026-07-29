import Foundation

enum ExerciseActivityType: String, CaseIterable, Identifiable, Codable {
    case strength
    case cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: AppLocalization.string("力量")
        case .cardio: AppLocalization.string("有氧")
        }
    }

    var systemImage: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .cardio: "figure.run"
        }
    }
}

enum ExerciseTrackingMode: String, Codable {
    case setsAndReps
    case duration

    var title: String {
        switch self {
        case .setsAndReps: AppLocalization.string("组数与次数")
        case .duration: AppLocalization.string("时长")
        }
    }
}

/// Branded, code-drawn artwork used for high-frequency exercises. Exercises
/// without a dedicated pose continue to use their semantic SF Symbol.
enum ExercisePoseIcon: String, Hashable {
    case benchPress
    case pushUp
    case pullUp
    case strengthRow
    case deadlift
    case squat
    case lunge
    case overheadPress
    case curl
    case triceps
    case plank
    case running
    case cycling
    case cardioRow
    case jumpRope
}

enum ExerciseBodyPart: String, CaseIterable, Identifiable, Codable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case fullBody

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: AppLocalization.string("胸部")
        case .back: AppLocalization.string("背部")
        case .legs: AppLocalization.string("腿部")
        case .shoulders: AppLocalization.string("肩部")
        case .arms: AppLocalization.string("手臂")
        case .core: AppLocalization.string("核心")
        case .fullBody: AppLocalization.string("全身")
        }
    }

    var systemImage: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .legs: "figure.step.training"
        case .shoulders: "figure.cross.training"
        case .arms: "dumbbell.fill"
        case .core: "figure.core.training"
        case .fullBody: "figure.mixed.cardio"
        }
    }
}

struct ExerciseDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let activityType: ExerciseActivityType
    let trackingMode: ExerciseTrackingMode
    let bodyPart: ExerciseBodyPart?
    let systemImage: String
    let poseIcon: ExercisePoseIcon?
    let defaultSets: Int
    let defaultReps: Int
    let defaultDurationSeconds: Int

    init(
        id: String,
        name: String,
        activityType: ExerciseActivityType = .strength,
        trackingMode: ExerciseTrackingMode = .setsAndReps,
        bodyPart: ExerciseBodyPart? = nil,
        systemImage: String? = nil,
        poseIcon: ExercisePoseIcon? = nil,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        defaultDurationSeconds: Int = 20 * 60
    ) {
        self.id = id
        self.name = name
        self.activityType = activityType
        self.trackingMode = trackingMode
        self.bodyPart = bodyPart
        self.systemImage = systemImage ?? activityType.systemImage
        self.poseIcon = poseIcon
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultDurationSeconds = defaultDurationSeconds
    }

    var subtitle: String {
        switch activityType {
        case .strength:
            return [bodyPart?.title, activityType.title].compactMap { $0 }.joined(separator: " · ")
        case .cardio:
            return "\(activityType.title) · \(trackingMode.title)"
        }
    }

    var localizedName: String {
        AppLocalization.string(name)
    }

    func localizedName(languageIdentifier: String) -> String {
        AppLocalization.string(name, languageIdentifier: languageIdentifier)
    }
}

enum ExerciseFormatting {
    static func duration(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds >= 3600 {
            return String(format: "%d:%02d:%02d", safeSeconds / 3600, (safeSeconds % 3600) / 60, safeSeconds % 60)
        }
        return String(format: "%d:%02d", safeSeconds / 60, safeSeconds % 60)
    }

    static func shortDuration(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let remainingSeconds = safeSeconds % 60

        if hours > 0 {
            var parts = [AppLocalization.format("%lld 小时", hours)]
            if minutes > 0 { parts.append(AppLocalization.format("%lld 分钟", minutes)) }
            if remainingSeconds > 0 { parts.append(AppLocalization.format("%lld 秒", remainingSeconds)) }
            return parts.joined(separator: " ")
        }
        if remainingSeconds > 0 || minutes == 0 {
            return minutes > 0
                ? AppLocalization.format("%lld 分钟 %lld 秒", minutes, remainingSeconds)
                : AppLocalization.format("%lld 秒", remainingSeconds)
        }
        return AppLocalization.format("%lld 分钟", minutes)
    }
}
