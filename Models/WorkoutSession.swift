import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var sessionDate: Date
    var dayName: String
    var plannedSetCount: Int
    var completedSetCount: Int
    var plannedCardioCount: Int = 0
    var completedCardioCount: Int = 0
    var completedCardioDurationSeconds: Int = 0
    var isComplete: Bool
    var startedAt: Date
    var completedAt: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    var setLogs: [SetLog]

    @Relationship(deleteRule: .cascade, inverse: \CardioLog.session)
    var cardioLogs: [CardioLog]
    
    init(
        sessionDate: Date,
        dayName: String,
        plannedSetCount: Int = 0,
        completedSetCount: Int = 0,
        plannedCardioCount: Int = 0,
        completedCardioCount: Int = 0,
        completedCardioDurationSeconds: Int = 0,
        isComplete: Bool = false,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        setLogs: [SetLog] = [],
        cardioLogs: [CardioLog] = []
    ) {
        self.sessionDate = sessionDate
        self.dayName = dayName
        self.plannedSetCount = plannedSetCount
        self.completedSetCount = completedSetCount
        self.plannedCardioCount = plannedCardioCount
        self.completedCardioCount = completedCardioCount
        self.completedCardioDurationSeconds = completedCardioDurationSeconds
        self.isComplete = isComplete
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.setLogs = setLogs
        self.cardioLogs = cardioLogs
    }
    
    var completionRate: Double {
        let plannedUnits = plannedSetCount + plannedCardioCount
        guard plannedUnits > 0 else { return 0 }
        return Double(completedSetCount + completedCardioCount) / Double(plannedUnits)
    }

    var hasPlannedWork: Bool {
        plannedSetCount > 0 || plannedCardioCount > 0
    }
}
