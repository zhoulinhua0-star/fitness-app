import SwiftUI

/// The single exercise-identity component used across the app.
///
/// Resolution order:
/// 1. RepDay pose artwork for high-frequency library exercises.
/// 2. A weighted movement-family match for custom Chinese or English names.
/// 3. A semantic SF Symbol for the matched body part or cardio activity.
/// 4. The first character of a genuinely unknown custom strength exercise.
struct ExerciseIconTile: View {
    private let name: String
    private let activityType: ExerciseActivityType
    private let suppliedDefinition: ExerciseDefinition?
    private let suppliedTint: Color?
    private let size: CGFloat

    init(
        name: String,
        activityType: ExerciseActivityType = .strength,
        tint: Color? = nil,
        size: CGFloat = 44
    ) {
        self.name = name
        self.activityType = activityType
        self.suppliedDefinition = nil
        self.suppliedTint = tint
        self.size = size
    }

    init(
        definition: ExerciseDefinition,
        tint: Color? = nil,
        size: CGFloat = 44
    ) {
        self.name = definition.name
        self.activityType = definition.activityType
        self.suppliedDefinition = definition
        self.suppliedTint = tint
        self.size = size
    }

    private var definition: ExerciseDefinition? {
        suppliedDefinition ?? ExerciseLibrary.definition(named: name)
    }

    private var classification: ExerciseMovementClassification? {
        guard definition == nil else { return nil }
        return ExerciseMovementClassifier.classify(name: name, activityType: activityType)
    }

    private var artwork: ExerciseIconArtwork {
        ExerciseIconResolver.artwork(
            name: name,
            activityType: activityType,
            definition: definition,
            classification: classification
        )
    }

    private var tileTint: Color {
        suppliedTint ?? ExerciseIconResolver.tint(
            activityType: activityType,
            definition: definition,
            classification: classification
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(tileTint)

            switch artwork {
            case .pose(let pose):
                ExercisePoseGlyph(pose: pose)
                    .padding(size * 0.14)

            case .system(let systemImage):
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.Color.textPrimary)

            case .monogram(let character):
                Text(character)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private enum ExerciseIconArtwork {
    case pose(ExercisePoseIcon)
    case system(String)
    case monogram(String)
}

private enum ExerciseIconResolver {
    static func artwork(
        name: String,
        activityType: ExerciseActivityType,
        definition: ExerciseDefinition?,
        classification: ExerciseMovementClassification?
    ) -> ExerciseIconArtwork {
        if let pose = definition?.poseIcon {
            return .pose(pose)
        }
        if let definition {
            return .system(definition.systemImage)
        }
        if let pose = classification?.family.poseIcon {
            return .pose(pose)
        }
        if let systemImage = classification?.family.systemImage {
            return .system(systemImage)
        }
        if activityType == .cardio {
            return .system(ExerciseActivityType.cardio.systemImage)
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return .monogram(trimmed.first.map { String($0).uppercased() } ?? "·")
    }

    static func tint(
        activityType: ExerciseActivityType,
        definition: ExerciseDefinition?,
        classification: ExerciseMovementClassification?
    ) -> Color {
        if activityType == .cardio
            || definition?.activityType == .cardio
            || classification?.family.isCardio == true {
            return Theme.Color.tintMint
        }

        switch definition?.bodyPart ?? classification?.family.bodyPart {
        case .chest: return Theme.Color.tintPeach
        case .back: return Theme.Color.tintBlue
        case .legs: return Theme.Color.tintMint
        case .shoulders: return Theme.Color.tintPurple
        case .arms: return Theme.Color.accentSoft
        case .core: return Theme.Color.tintOrange
        case .fullBody: return Theme.Color.tintPurple
        case nil: return Theme.Color.surfaceMuted
        }
    }
}

private struct ExercisePoseGlyph: View {
    let pose: ExercisePoseIcon

    var body: some View {
        ZStack {
            ExerciseBodyShape(pose: pose)
                .stroke(
                    Theme.Color.textPrimary,
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )

            ExerciseEquipmentShape(pose: pose)
                .stroke(
                    Theme.Color.accent,
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct ExerciseBodyShape: Shape {
    let pose: ExercisePoseIcon

    func path(in rect: CGRect) -> Path {
        var path = Path()

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 100,
                y: rect.minY + rect.height * y / 100
            )
        }

        func line(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            path.move(to: point(first.0, first.1))
            for value in points.dropFirst() {
                path.addLine(to: point(value.0, value.1))
            }
        }

        func head(_ x: CGFloat, _ y: CGFloat, radius: CGFloat = 7) {
            path.addEllipse(
                in: CGRect(
                    x: point(x - radius, y - radius).x,
                    y: point(x - radius, y - radius).y,
                    width: rect.width * radius * 2 / 100,
                    height: rect.height * radius * 2 / 100
                )
            )
        }

        switch pose {
        case .benchPress:
            head(25, 47)
            line([(32, 50), (58, 50), (72, 60)])
            line([(43, 50), (43, 33), (50, 27)])
            line([(52, 50), (58, 33), (64, 27)])
            line([(72, 60), (84, 56)])
            line([(72, 60), (82, 74)])

        case .pushUp, .plank:
            head(22, 42)
            line([(30, 47), (63, 58), (84, 67)])
            line([(39, 50), (31, 68), (49, 68)])
            if pose == .pushUp {
                line([(63, 58), (79, 68)])
            }

        case .pullUp:
            head(50, 36)
            line([(50, 43), (50, 66)])
            line([(50, 47), (35, 30), (27, 20)])
            line([(50, 47), (65, 30), (73, 20)])
            line([(50, 66), (40, 84)])
            line([(50, 66), (60, 84)])

        case .strengthRow:
            head(31, 29)
            line([(37, 36), (57, 55)])
            line([(43, 42), (60, 53), (71, 61)])
            line([(57, 55), (47, 80)])
            line([(57, 55), (76, 74)])

        case .deadlift:
            head(39, 23)
            line([(42, 31), (56, 57)])
            line([(46, 39), (50, 69)])
            line([(56, 57), (43, 82)])
            line([(56, 57), (73, 82)])

        case .squat:
            head(50, 20)
            line([(50, 28), (50, 53)])
            line([(50, 37), (35, 32)])
            line([(50, 37), (65, 32)])
            line([(50, 53), (35, 68), (42, 85)])
            line([(50, 53), (65, 68), (74, 85)])

        case .lunge:
            head(43, 18)
            line([(43, 26), (45, 52)])
            line([(45, 35), (30, 42)])
            line([(45, 35), (60, 42)])
            line([(45, 52), (65, 66), (79, 84)])
            line([(45, 52), (30, 69), (20, 84)])

        case .overheadPress:
            head(50, 39)
            line([(50, 46), (50, 70)])
            line([(50, 50), (35, 37), (34, 20)])
            line([(50, 50), (65, 37), (66, 20)])
            line([(50, 70), (40, 86)])
            line([(50, 70), (60, 86)])

        case .curl:
            head(50, 24)
            line([(50, 32), (50, 66)])
            line([(50, 39), (34, 47), (41, 59)])
            line([(50, 39), (66, 47), (59, 59)])
            line([(50, 66), (40, 85)])
            line([(50, 66), (60, 85)])

        case .triceps:
            head(40, 24)
            line([(43, 32), (50, 63)])
            line([(46, 40), (61, 48), (58, 67)])
            line([(50, 63), (40, 84)])
            line([(50, 63), (64, 84)])

        case .running:
            head(48, 20)
            line([(47, 28), (47, 54)])
            line([(47, 36), (31, 45)])
            line([(47, 36), (63, 27)])
            line([(47, 54), (30, 72), (17, 71)])
            line([(47, 54), (64, 69), (81, 84)])

        case .cycling:
            head(52, 17)
            line([(50, 25), (41, 48)])
            line([(48, 31), (66, 40)])
            line([(41, 48), (53, 62), (42, 75)])
            line([(41, 48), (66, 72)])

        case .cardioRow:
            head(35, 25)
            line([(39, 33), (52, 54)])
            line([(43, 39), (63, 49)])
            line([(52, 54), (70, 67), (84, 66)])

        case .jumpRope:
            head(50, 18)
            line([(50, 26), (50, 59)])
            line([(50, 35), (31, 45)])
            line([(50, 35), (69, 45)])
            line([(50, 59), (40, 84)])
            line([(50, 59), (60, 84)])
        }

        return path
    }
}

private struct ExerciseEquipmentShape: Shape {
    let pose: ExercisePoseIcon

    func path(in rect: CGRect) -> Path {
        var path = Path()

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * x / 100,
                y: rect.minY + rect.height * y / 100
            )
        }

        func line(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            path.move(to: point(first.0, first.1))
            for value in points.dropFirst() {
                path.addLine(to: point(value.0, value.1))
            }
        }

        func circle(_ x: CGFloat, _ y: CGFloat, radius: CGFloat) {
            path.addEllipse(
                in: CGRect(
                    x: point(x - radius, y - radius).x,
                    y: point(x - radius, y - radius).y,
                    width: rect.width * radius * 2 / 100,
                    height: rect.height * radius * 2 / 100
                )
            )
        }

        switch pose {
        case .benchPress:
            line([(17, 59), (68, 59)])
            line([(31, 25), (73, 25)])
            line([(29, 20), (29, 30)])
            line([(75, 20), (75, 30)])

        case .pushUp, .plank:
            line([(14, 72), (90, 72)])

        case .pullUp:
            line([(18, 17), (82, 17)])

        case .strengthRow:
            line([(64, 62), (90, 62)])
            line([(66, 56), (66, 68)])
            line([(88, 56), (88, 68)])

        case .deadlift:
            line([(24, 70), (84, 70)])
            line([(27, 63), (27, 77)])
            line([(81, 63), (81, 77)])

        case .squat:
            line([(24, 31), (76, 31)])
            line([(27, 25), (27, 37)])
            line([(73, 25), (73, 37)])

        case .lunge:
            circle(28, 44, radius: 5)
            circle(62, 44, radius: 5)

        case .overheadPress:
            line([(24, 16), (43, 16)])
            line([(57, 16), (76, 16)])
            line([(27, 11), (27, 21)])
            line([(73, 11), (73, 21)])

        case .curl:
            line([(34, 58), (46, 58)])
            line([(54, 58), (66, 58)])
            line([(36, 53), (36, 63)])
            line([(64, 53), (64, 63)])

        case .triceps:
            line([(75, 14), (75, 42), (62, 48)])
            line([(68, 45), (58, 45)])

        case .running:
            line([(13, 88), (84, 88)])

        case .cycling:
            circle(27, 73, radius: 16)
            circle(73, 73, radius: 16)
            line([(27, 73), (43, 50), (58, 73), (27, 73)])
            line([(43, 50), (69, 47), (73, 73)])

        case .cardioRow:
            line([(26, 72), (89, 72)])
            line([(42, 58), (59, 58)])
            line([(63, 49), (82, 39)])

        case .jumpRope:
            path.move(to: point(31, 45))
            path.addCurve(
                to: point(69, 45),
                control1: point(4, 94),
                control2: point(96, 94)
            )
        }

        return path
    }
}
