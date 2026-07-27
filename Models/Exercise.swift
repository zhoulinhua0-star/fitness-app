import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var sets: Int
    var reps: Int
    var order: Int
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
        self.restSeconds = restSeconds
        self.lastCompletedDate = lastCompletedDate
        self.sessionDate = sessionDate
        self.completedSetCount = completedSetCount
        self.isImprov = isImprov
        self.isRemovedFromImprov = isRemovedFromImprov
    }
}

extension Exercise {
    private var isSessionToday: Bool {
        guard let sessionDate else { return false }
        return Calendar.current.isDateInToday(sessionDate)
    }
    
    func resetSessionIfNeeded(for date: Date = .now) {
        guard let sessionDate else { return }
        if !Calendar.current.isDate(sessionDate, inSameDayAs: date) {
            self.sessionDate = nil
            completedSetCount = 0
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
        guard sets > 0 else { return 0 }
        return Double(effectiveCompletedSetCount) / Double(sets)
    }
    
    var isFullyCompletedToday: Bool {
        isSessionToday && effectiveCompletedSetCount >= sets
    }
    
    @discardableResult
    func completeNextSet(at date: Date = .now) -> Bool {
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
        prepareForTodayIfNeeded()
        guard completedSetCount > 0 else { return false }
        
        completedSetCount -= 1
        lastCompletedDate = nil
        return true
    }
    
    func completeAllRemainingSets(at date: Date = .now) {
        prepareForTodayIfNeeded(at: date)
        guard completedSetCount < sets else { return }
        
        sessionDate = date
        completedSetCount = sets
        lastCompletedDate = date
    }
}
