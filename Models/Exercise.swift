import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var sets: Int
    var reps: Int
    var order: Int
    var lastCompletedDate: Date? // 👈 核心：记录最后一次打卡的日期
    
    init(name: String, sets: Int, reps: Int, order: Int = 0, lastCompletedDate: Date? = nil) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.order = order
        self.lastCompletedDate = lastCompletedDate
    }
}
