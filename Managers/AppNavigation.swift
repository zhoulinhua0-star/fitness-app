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
    var pendingRestTimerID: String?

    private init() {}

    func openRestTimer(_ timerID: String) {
        selectedTab = .today
        pendingRestTimerID = timerID
    }
}
