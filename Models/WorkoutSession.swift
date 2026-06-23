import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var sessionDate: Date
    var dayName: String
    var plannedSetCount: Int
    var completedSetCount: Int
    var isComplete: Bool
    var startedAt: Date
    var completedAt: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    var setLogs: [SetLog]
    
    init(
        sessionDate: Date,
        dayName: String,
        plannedSetCount: Int = 0,
        completedSetCount: Int = 0,
        isComplete: Bool = false,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        setLogs: [SetLog] = []
    ) {
        self.sessionDate = sessionDate
        self.dayName = dayName
        self.plannedSetCount = plannedSetCount
        self.completedSetCount = completedSetCount
        self.isComplete = isComplete
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.setLogs = setLogs
    }
    
    var completionRate: Double {
        guard plannedSetCount > 0 else { return 0 }
        return Double(completedSetCount) / Double(plannedSetCount)
    }
}
