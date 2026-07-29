import Foundation

enum ExerciseMovementFamily: String {
    case horizontalPush
    case pushUp
    case chestIsolation
    case verticalPull
    case horizontalPull
    case backAccessory
    case hipHinge
    case squat
    case lunge
    case legAccessory
    case calfRaise
    case verticalPush
    case shoulderAccessory
    case elbowFlexion
    case elbowExtension
    case armAccessory
    case plank
    case coreAccessory
    case fullBody
    case running
    case cycling
    case cardioRowing
    case jumpRope
    case swimming
    case walking
    case hiking
    case dancing
    case stairClimbing
    case elliptical

    var poseIcon: ExercisePoseIcon? {
        switch self {
        case .horizontalPush: .benchPress
        case .pushUp: .pushUp
        case .verticalPull: .pullUp
        case .horizontalPull: .strengthRow
        case .hipHinge: .deadlift
        case .squat: .squat
        case .lunge: .lunge
        case .verticalPush: .overheadPress
        case .elbowFlexion: .curl
        case .elbowExtension: .triceps
        case .plank: .plank
        case .running: .running
        case .cycling: .cycling
        case .cardioRowing: .cardioRow
        case .jumpRope: .jumpRope
        default: nil
        }
    }

    var bodyPart: ExerciseBodyPart? {
        switch self {
        case .horizontalPush, .pushUp, .chestIsolation: .chest
        case .verticalPull, .horizontalPull, .backAccessory, .hipHinge: .back
        case .squat, .lunge, .legAccessory, .calfRaise: .legs
        case .verticalPush, .shoulderAccessory: .shoulders
        case .elbowFlexion, .elbowExtension, .armAccessory: .arms
        case .plank, .coreAccessory: .core
        case .fullBody: .fullBody
        default: nil
        }
    }

    var systemImage: String? {
        switch self {
        case .swimming: "figure.pool.swim"
        case .walking: "figure.walk"
        case .hiking: "figure.hiking"
        case .dancing: "figure.dance"
        case .stairClimbing: "figure.stair.stepper"
        case .elliptical: "figure.elliptical"
        default: bodyPart?.systemImage
        }
    }

    var isCardio: Bool {
        switch self {
        case .running, .cycling, .cardioRowing, .jumpRope,
             .swimming, .walking, .hiking, .dancing,
             .stairClimbing, .elliptical:
            true
        default:
            false
        }
    }
}

struct ExerciseMovementClassification: Equatable {
    let family: ExerciseMovementFamily
}

enum ExerciseMovementClassifier {
    static func classify(
        name: String,
        activityType: ExerciseActivityType
    ) -> ExerciseMovementClassification? {
        let normalizedName = normalize(name)
        guard !normalizedName.isEmpty else { return nil }

        let candidates = rules.compactMap { rule -> Candidate? in
            let matches = rule.terms.filter {
                contains(normalizedName, normalizedPattern: $0.normalizedValue)
            }
            guard !matches.isEmpty else { return nil }

            var score = matches.reduce(0) { $0 + $1.weight }
            score += rule.activityType == activityType ? 8 : -8
            score -= rule.penalties
                .filter { contains(normalizedName, normalizedPattern: $0.normalizedValue) }
                .reduce(0) { $0 + $1.weight }

            if matches.contains(where: { $0.normalizedValue == normalizedName }) {
                score += 8
            }

            return Candidate(
                family: rule.family,
                score: score,
                specificity: matches.map(\.normalizedValue.count).max() ?? 0,
                priority: rule.priority
            )
        }

        guard let best = candidates.max(by: { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            if lhs.specificity != rhs.specificity { return lhs.specificity < rhs.specificity }
            return lhs.priority < rhs.priority
        }), best.score >= 10 else {
            return nil
        }

        return ExerciseMovementClassification(family: best.family)
    }
}

private extension ExerciseMovementClassifier {
    struct WeightedTerm {
        let normalizedValue: String
        let weight: Int

        init(_ value: String, _ weight: Int) {
            self.normalizedValue = ExerciseMovementClassifier.normalize(value)
            self.weight = weight
        }
    }

    struct Rule {
        let family: ExerciseMovementFamily
        let activityType: ExerciseActivityType
        let terms: [WeightedTerm]
        let penalties: [WeightedTerm]
        let priority: Int
    }

    struct Candidate {
        let family: ExerciseMovementFamily
        let score: Int
        let specificity: Int
        let priority: Int
    }

    static let rules: [Rule] = [
        rule(.horizontalPush, .strength, 90, [
            term("器械推胸", 30), term("machine chest press", 30),
            term("bench press", 28), term("floor press", 28),
            term("卧推", 26), term("推胸", 24), term("chest press", 24)
        ]),
        rule(.pushUp, .strength, 95, [
            term("俯卧撑", 30), term("push up", 30), term("push ups", 30),
            term("pushup", 30), term("pushups", 30)
        ]),
        rule(.chestIsolation, .strength, 55, [
            term("器械夹胸", 28), term("pec deck", 28), term("cable crossover", 28),
            term("飞鸟", 22), term("夹胸", 22), term("chest fly", 22),
            term("胸部", 10), term("chest", 10), term("pec", 10)
        ]),

        rule(.verticalPull, .strength, 90, [
            term("引体向上", 30), term("高位下拉", 30), term("直臂下压", 30),
            term("pull up", 28), term("pull ups", 28), term("pullup", 28),
            term("pullups", 28), term("chin up", 28), term("chin ups", 28),
            term("chinup", 28), term("chinups", 28),
            term("lat pulldown", 28), term("lat pull down", 28),
            term("straight arm pulldown", 30), term("下拉", 18), term("引体", 18)
        ]),
        rule(.horizontalPull, .strength, 80, [
            term("坐姿器械划船", 32), term("胸托划船", 30), term("直立划船", 10),
            term("器械划船", 28), term("坐姿划船", 28), term("杠铃划船", 28),
            term("哑铃划船", 28), term("t杠划船", 28),
            term("machine row", 28), term("seated cable row", 30),
            term("chest supported row", 30), term("barbell row", 28),
            term("dumbbell row", 28), term("t bar row", 28),
            term("pendlay row", 28), term("cable row", 26),
            term("seated row", 24), term("划船", 16),
            term("rowing", 12), term("rows", 12), term("row", 12)
        ], penalties: [
            term("划船机", 40), term("划船器", 40), term("赛艇", 40),
            term("rowing machine", 40), term("indoor rowing", 40), term("rower", 40),
            term("直立划船", 20), term("upright row", 40)
        ]),
        rule(.backAccessory, .strength, 40, [
            term("背阔", 12), term("背部", 10), term("upper back", 12),
            term("lower back", 12), term("lat", 10), term("back", 9)
        ]),

        rule(.hipHinge, .strength, 90, [
            term("罗马尼亚硬拉", 32), term("romanian deadlift", 32),
            term("直腿硬拉", 30), term("stiff leg deadlift", 30),
            term("硬拉", 26), term("deadlift", 26), term("rdl", 24)
        ]),
        rule(.squat, .strength, 85, [
            term("哈克深蹲", 30), term("hack squat", 30),
            term("前蹲", 26), term("front squat", 28),
            term("深蹲", 24), term("squat", 24)
        ]),
        rule(.lunge, .strength, 90, [
            term("保加利亚深蹲", 34), term("bulgarian split squat", 34),
            term("分腿蹲", 30), term("split squat", 30),
            term("弓步蹲", 28), term("弓步", 24), term("lunge", 26)
        ]),
        rule(.legAccessory, .strength, 75, [
            term("腿弯举", 30), term("leg curl", 30), term("hamstring curl", 32),
            term("腿伸展", 30), term("leg extension", 30),
            term("腿举", 28), term("leg press", 28),
            term("臀推", 28), term("hip thrust", 28),
            term("臀桥", 26), term("glute bridge", 26),
            term("髋外展", 26), term("hip abduction", 26),
            term("髋内收", 26), term("hip adduction", 26),
            term("腿部", 10), term("hamstring", 10), term("quadriceps", 10),
            term("glute", 10), term("leg", 9), term("臀", 8), term("腿", 8)
        ]),
        rule(.calfRaise, .strength, 90, [
            term("小腿提踵", 30), term("提踵", 26),
            term("calf raise", 30), term("calves", 16), term("小腿", 14)
        ]),

        rule(.verticalPush, .strength, 85, [
            term("阿诺德推举", 32), term("arnold press", 32),
            term("肩上推举", 30), term("overhead press", 30),
            term("military press", 30), term("shoulder press", 28),
            term("推举", 18)
        ]),
        rule(.shoulderAccessory, .strength, 75, [
            term("直立划船", 34), term("upright row", 34),
            term("侧平举", 30), term("lateral raise", 30),
            term("前平举", 30), term("front raise", 30),
            term("反向飞鸟", 28), term("reverse fly", 28),
            term("面拉", 28), term("face pull", 28),
            term("肩部", 10), term("shoulder", 10), term("deltoid", 10), term("delt", 9)
        ]),

        rule(.elbowFlexion, .strength, 80, [
            term("腿弯举", 8), term("二头弯举", 30), term("锤式弯举", 30),
            term("preacher curl", 30), term("hammer curl", 30),
            term("biceps curl", 28), term("哑铃弯举", 26),
            term("弯举", 18), term("curl", 18)
        ], penalties: [
            term("腿弯举", 35), term("leg curl", 35), term("hamstring curl", 35)
        ]),
        rule(.elbowExtension, .strength, 85, [
            term("绳索下压", 32), term("三头下压", 32),
            term("triceps pushdown", 32), term("tricep pushdown", 32),
            term("triceps push down", 32), term("tricep push down", 32),
            term("颅骨破碎者", 30), term("skull crusher", 30),
            term("臂屈伸", 28), term("triceps extension", 28),
            term("三头", 14), term("triceps", 14), term("tricep", 14),
            term("下压", 12)
        ], penalties: [
            term("直臂下压", 30), term("straight arm pulldown", 30)
        ]),
        rule(.armAccessory, .strength, 35, [
            term("手臂", 10), term("二头", 10), term("biceps", 10),
            term("三头", 10), term("triceps", 10), term("arm", 9)
        ]),

        rule(.plank, .strength, 90, [
            term("侧平板", 30), term("side plank", 30),
            term("平板支撑", 28), term("plank", 28), term("平板", 18)
        ]),
        rule(.coreAccessory, .strength, 70, [
            term("俄罗斯转体", 30), term("russian twist", 30),
            term("悬挂举腿", 30), term("hanging leg raise", 30),
            term("卷腹", 28), term("crunch", 28), term("sit up", 26),
            term("sit ups", 26), term("situp", 26), term("situps", 26),
            term("核心", 12), term("core", 12), term("腹", 9), term("abs", 10)
        ]),
        rule(.fullBody, .strength, 65, [
            term("波比跳", 30), term("burpee", 30),
            term("壶铃摇摆", 30), term("kettlebell swing", 30),
            term("农夫行走", 28), term("farmer carry", 28),
            term("抓举", 28), term("snatch", 28),
            term("挺举", 28), term("clean and jerk", 28),
            term("全身", 10), term("full body", 10)
        ]),

        rule(.running, .cardio, 90, [
            term("跑步机", 32), term("treadmill", 32),
            term("户外跑步", 30), term("慢跑", 28), term("冲刺跑", 28),
            term("running", 24), term("跑步", 24), term("jogging", 24),
            term("sprint", 22), term("run", 18), term("jog", 18), term("跑", 12)
        ]),
        rule(.cycling, .cardio, 90, [
            term("动感单车", 32), term("stationary bike", 32), term("spin bike", 32),
            term("户外骑行", 30), term("骑行", 26), term("自行车", 26),
            term("cycling", 24), term("bicycle", 24),
            term("cycle", 20), term("bike", 20), term("单车", 20)
        ]),
        rule(.cardioRowing, .cardio, 100, [
            term("划船机", 36), term("划船器", 36), term("赛艇", 34),
            term("rowing machine", 36), term("indoor rowing", 34), term("rower", 34),
            term("rowing", 10), term("划船", 10), term("row", 8)
        ]),
        rule(.jumpRope, .cardio, 95, [
            term("跳绳", 32), term("jump rope", 32), term("skipping rope", 32)
        ]),
        rule(.swimming, .cardio, 90, [
            term("自由泳", 32), term("蛙泳", 32), term("仰泳", 32), term("蝶泳", 32),
            term("freestyle swimming", 32), term("breaststroke", 32),
            term("backstroke", 32), term("butterfly stroke", 32),
            term("游泳", 30), term("swimming", 30), term("swim", 24)
        ]),
        rule(.walking, .cardio, 70, [
            term("快走", 30), term("健走", 30), term("步行", 26),
            term("walking", 26), term("walk", 20), term("走路", 22)
        ]),
        rule(.hiking, .cardio, 80, [
            term("徒步", 30), term("登山", 28), term("hiking", 30), term("hike", 24)
        ]),
        rule(.dancing, .cardio, 75, [
            term("有氧操", 32), term("健身操", 30), term("aerobics", 32),
            term("舞蹈", 26), term("dance", 24), term("跳舞", 24)
        ]),
        rule(.stairClimbing, .cardio, 85, [
            term("爬楼机", 32), term("楼梯机", 32), term("stair climber", 32),
            term("stair stepper", 32), term("stairmaster", 32), term("stepmill", 32),
            term("爬楼梯", 28), term("爬楼", 26), term("stairs", 24)
        ]),
        rule(.elliptical, .cardio, 85, [
            term("椭圆机", 32), term("elliptical", 32)
        ])
    ]

    static func rule(
        _ family: ExerciseMovementFamily,
        _ activityType: ExerciseActivityType,
        _ priority: Int,
        _ terms: [WeightedTerm],
        penalties: [WeightedTerm] = []
    ) -> Rule {
        Rule(
            family: family,
            activityType: activityType,
            terms: terms,
            penalties: penalties,
            priority: priority
        )
    }

    static func term(_ value: String, _ weight: Int) -> WeightedTerm {
        WeightedTerm(value, weight)
    }

    static func normalize(_ value: String) -> String {
        let halfWidth = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
        let lowered = halfWidth.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
        }
        return scalars
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func contains(_ name: String, normalizedPattern pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        if pattern.unicodeScalars.contains(where: { $0.value >= 0x2E80 }) {
            return name.contains(pattern)
        }
        return " \(name) ".contains(" \(pattern) ")
    }
}
