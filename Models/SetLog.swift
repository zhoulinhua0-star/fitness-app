import Foundation
import SwiftData

@Model
final class SetLog {
    var exerciseName: String
    var setIndex: Int
    var reps: Int
    var weight: Double?
    var loggedAt: Date
    
    var session: WorkoutSession?
    
    init(
        exerciseName: String,
        setIndex: Int,
        reps: Int,
        weight: Double? = nil,
        loggedAt: Date = .now
    ) {
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.loggedAt = loggedAt
    }
}
