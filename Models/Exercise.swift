import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var sets: Int
    var reps: Int
    var order: Int
    var activityTypeRaw: String = ExerciseActivityType.strength.rawValue
    var trackingModeRaw: String = ExerciseTrackingMode.setsAndReps.rawValue
    var targetDurationSeconds: Int = 0
    var elapsedDurationSeconds: Int = 0
    var cardioStartedAt: Date?
    /// Per-exercise rest duration. Nil falls back to the app-wide default.
    var restSeconds: Int?
    var lastCompletedDate: Date?
    var sessionDate: Date?
    var completedSetCount: Int
    /// True for ad-hoc "即兴" exercises that live only for today and are not
    /// part of any persistent weekly plan (not attached to a WorkoutDay).
    var isImprov: Bool = false
    /// Keeps a removed improv exercise around until the session ends so any
    /// completed sets remain part of today's history and progress.
    var isRemovedFromImprov: Bool = false

    init(
        name: String,
        sets: Int,
        reps: Int,
        order: Int = 0,
        activityType: ExerciseActivityType = .strength,
        trackingMode: ExerciseTrackingMode = .setsAndReps,
        targetDurationSeconds: Int = 0,
        elapsedDurationSeconds: Int = 0,
        cardioStartedAt: Date? = nil,
        restSeconds: Int? = nil,
        lastCompletedDate: Date? = nil,
        sessionDate: Date? = nil,
        completedSetCount: Int = 0,
        isImprov: Bool = false,
        isRemovedFromImprov: Bool = false
    ) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.order = order
        self.activityTypeRaw = activityType.rawValue
        self.trackingModeRaw = trackingMode.rawValue
        self.targetDurationSeconds = targetDurationSeconds
        self.elapsedDurationSeconds = elapsedDurationSeconds
        self.cardioStartedAt = cardioStartedAt
        self.restSeconds = restSeconds
        self.lastCompletedDate = lastCompletedDate
        self.sessionDate = sessionDate
        self.completedSetCount = completedSetCount
        self.isImprov = isImprov
        self.isRemovedFromImprov = isRemovedFromImprov
    }
}

extension Exercise {
    var activityType: ExerciseActivityType {
        get { ExerciseActivityType(rawValue: activityTypeRaw) ?? .strength }
        set { activityTypeRaw = newValue.rawValue }
    }

    var trackingMode: ExerciseTrackingMode {
        get { ExerciseTrackingMode(rawValue: trackingModeRaw) ?? .setsAndReps }
        set { trackingModeRaw = newValue.rawValue }
    }

    var isCardio: Bool {
        activityType == .cardio || trackingMode == .duration
    }

    private var isSessionToday: Bool {
        guard let sessionDate else { return false }
        return Calendar.current.isDateInToday(sessionDate)
    }
    
    func resetSessionIfNeeded(for date: Date = .now) {
        guard let sessionDate else { return }
        if !Calendar.current.isDate(sessionDate, inSameDayAs: date) {
            self.sessionDate = nil
            completedSetCount = 0
            elapsedDurationSeconds = 0
            cardioStartedAt = nil
            lastCompletedDate = nil
        }
    }
    
    func clampCompletedSetCount() {
        if completedSetCount > sets {
            completedSetCount = sets
        }
        if completedSetCount < 0 {
            completedSetCount = 0
        }
    }
    
    func prepareForTodayIfNeeded(at date: Date = .now) {
        resetSessionIfNeeded(for: date)
        clampCompletedSetCount()
    }
    
    var effectiveCompletedSetCount: Int {
        guard isSessionToday else { return 0 }
        return min(completedSetCount, sets)
    }
    
    var setProgress: Double {
        guard !isCardio else { return cardioProgress() }
        guard sets > 0 else { return 0 }
        return Double(effectiveCompletedSetCount) / Double(sets)
    }
    
    var isFullyCompletedToday: Bool {
        if isCardio {
            guard isSessionToday, let lastCompletedDate else { return false }
            return Calendar.current.isDateInToday(lastCompletedDate)
        }
        return isSessionToday && effectiveCompletedSetCount >= sets
    }
    
    @discardableResult
    func completeNextSet(at date: Date = .now) -> Bool {
        guard !isCardio else { return false }
        prepareForTodayIfNeeded(at: date)
        guard completedSetCount < sets else { return false }
        
        if !isSessionToday {
            sessionDate = date
            completedSetCount = 0
        }
        
        completedSetCount += 1
        
        if completedSetCount >= sets {
            lastCompletedDate = date
        } else {
            lastCompletedDate = nil
        }
        
        return true
    }
    
    @discardableResult
    func undoLastSet() -> Bool {
        guard !isCardio else { return false }
        prepareForTodayIfNeeded()
        guard completedSetCount > 0 else { return false }
        
        completedSetCount -= 1
        lastCompletedDate = nil
        return true
    }
    
    func completeAllRemainingSets(at date: Date = .now) {
        guard !isCardio else { return }
        prepareForTodayIfNeeded(at: date)
        guard completedSetCount < sets else { return }
        
        sessionDate = date
        completedSetCount = sets
        lastCompletedDate = date
    }

    func cardioElapsedSeconds(at date: Date = .now) -> Int {
        guard sessionDate.map({ Calendar.current.isDate($0, inSameDayAs: date) }) ?? false else { return 0 }
        let runningSeconds = cardioStartedAt.map { max(0, Int(date.timeIntervalSince($0))) } ?? 0
        return max(0, elapsedDurationSeconds + runningSeconds)
    }

    func cardioProgress(at date: Date = .now) -> Double {
        guard targetDurationSeconds > 0 else { return isFullyCompletedToday ? 1 : 0 }
        return min(1, Double(cardioElapsedSeconds(at: date)) / Double(targetDurationSeconds))
    }

    func startCardio(at date: Date = .now) {
        guard isCardio, !isFullyCompletedToday else { return }
        prepareForTodayIfNeeded(at: date)
        if !isSessionToday {
            sessionDate = date
            elapsedDurationSeconds = 0
        }
        guard cardioStartedAt == nil else { return }
        cardioStartedAt = date
    }

    func pauseCardio(at date: Date = .now) {
        guard isCardio, let cardioStartedAt else { return }
        elapsedDurationSeconds += max(0, Int(date.timeIntervalSince(cardioStartedAt)))
        self.cardioStartedAt = nil
    }

    @discardableResult
    func finishCardio(at date: Date = .now) -> Int {
        guard isCardio else { return 0 }
        pauseCardio(at: date)
        if sessionDate == nil {
            sessionDate = date
        }
        lastCompletedDate = date
        return elapsedDurationSeconds
    }

    func resetCardio() {
        guard isCardio else { return }
        elapsedDurationSeconds = 0
        cardioStartedAt = nil
        lastCompletedDate = nil
        sessionDate = nil
    }
}
