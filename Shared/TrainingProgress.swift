import Foundation

enum TrainingLevel: String, CaseIterable, Identifiable {
    case beginning
    case findingRhythm
    case buildingRhythm
    case trainingSteadily
    case persistent
    case longTerm
    case forged

    var id: Self { self }

    var number: Int {
        Self.allCases.firstIndex(of: self).map { $0 + 1 } ?? 1
    }

    var title: String {
        switch self {
        case .beginning: AppLocalization.string("启程")
        case .findingRhythm: AppLocalization.string("渐入佳境")
        case .buildingRhythm: AppLocalization.string("形成节奏")
        case .trainingSteadily: AppLocalization.string("稳定训练")
        case .persistent: AppLocalization.string("坚持者")
        case .longTerm: AppLocalization.string("长期主义")
        case .forged: AppLocalization.string("千锤百炼")
        }
    }

    var requiredTrainingDays: Int {
        switch self {
        case .beginning: 1
        case .findingRhythm: 7
        case .buildingRhythm: 30
        case .trainingSteadily: 75
        case .persistent: 150
        case .longTerm: 300
        case .forged: 500
        }
    }
}

struct TrainingProgress {
    let effectiveTrainingDays: Int

    var currentLevel: TrainingLevel? {
        TrainingLevel.allCases.last {
            effectiveTrainingDays >= $0.requiredTrainingDays
        }
    }

    var nextLevel: TrainingLevel? {
        TrainingLevel.allCases.first {
            effectiveTrainingDays < $0.requiredTrainingDays
        }
    }

    var daysToNextLevel: Int {
        guard let nextLevel else { return 0 }
        return max(0, nextLevel.requiredTrainingDays - effectiveTrainingDays)
    }

    var progressFraction: Double {
        guard let nextLevel else { return 1 }
        let lowerBound = currentLevel?.requiredTrainingDays ?? 0
        let completed = effectiveTrainingDays - lowerBound
        let required = nextLevel.requiredTrainingDays - lowerBound
        guard required > 0 else { return 1 }
        return min(max(Double(completed) / Double(required), 0), 1)
    }
}
