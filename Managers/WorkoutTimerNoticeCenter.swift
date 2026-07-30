import Foundation
import Observation

struct WorkoutTimerNotice: Equatable, Identifiable {
    enum Kind: Equatable {
        case completed
        case cardioGoal
        case warning
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}

@MainActor
@Observable
final class WorkoutTimerNoticeCenter {
    static let shared = WorkoutTimerNoticeCenter()

    private(set) var notice: WorkoutTimerNotice?

    private var dismissTask: Task<Void, Never>?
    private var queuedNotices: [WorkoutTimerNotice] = []

    private init() {}

    func present(kind: WorkoutTimerNotice.Kind, title: String, message: String) {
        let newNotice = WorkoutTimerNotice(kind: kind, title: title, message: message)
        guard notice == nil else {
            queuedNotices.append(newNotice)
            return
        }
        show(newNotice)
    }

    func dismiss() {
        dismissTask?.cancel()
        notice = nil
        showNextIfNeeded()
    }

    private func show(_ newNotice: WorkoutTimerNotice) {
        notice = newNotice
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.notice = nil
            self?.showNextIfNeeded()
        }
    }

    private func showNextIfNeeded() {
        guard notice == nil, !queuedNotices.isEmpty else { return }
        show(queuedNotices.removeFirst())
    }
}
