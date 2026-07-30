import Observation

enum AppTab: Hashable {
    case today
    case analytics
    case plan
    case profile
}

@MainActor
@Observable
final class AppNavigation {
    static let shared = AppNavigation()

    var selectedTab: AppTab = .today
    var pendingTimerExerciseID: String?

    private init() {}

    func openTimerExercise(_ timerID: String) {
        selectedTab = .today
        pendingTimerExerciseID = timerID
    }
}
