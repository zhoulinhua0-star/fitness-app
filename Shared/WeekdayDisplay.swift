import Foundation

enum WeekdayDisplay {
    private static let labels: [String: String] = [
        "周一": "Mon",
        "周二": "Tue",
        "周三": "Wed",
        "周四": "Thu",
        "周五": "Fri",
        "周六": "Sat",
        "周日": "Sun"
    ]
    
    static func label(for storedDayName: String) -> String {
        labels[storedDayName] ?? storedDayName
    }
}
