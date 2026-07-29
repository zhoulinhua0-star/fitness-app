import Foundation
import SwiftData

@Model
final class CardioLog {
    var exerciseName: String
    var targetDurationSeconds: Int
    var durationSeconds: Int
    var loggedAt: Date

    var session: WorkoutSession?

    init(
        exerciseName: String,
        targetDurationSeconds: Int,
        durationSeconds: Int,
        loggedAt: Date = .now
    ) {
        self.exerciseName = exerciseName
        self.targetDurationSeconds = targetDurationSeconds
        self.durationSeconds = durationSeconds
        self.loggedAt = loggedAt
    }
}
