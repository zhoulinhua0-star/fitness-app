import Foundation
import Observation

@Observable
final class LocalProfileStore {
    static let shared = LocalProfileStore()

    static let displayNameLimit = 20
    static let bioLimit = 50

    private enum Keys {
        static let displayName = "localProfileDisplayName"
        static let bio = "localProfileBio"
    }

    private let defaults = UserDefaults.standard

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    var bio: String {
        didSet { defaults.set(bio, forKey: Keys.bio) }
    }

    var hasDisplayName: Bool {
        !displayName.isEmpty
    }

    private init() {
        displayName = Self.normalized(
            defaults.string(forKey: Keys.displayName) ?? "",
            limit: Self.displayNameLimit
        )
        bio = Self.normalized(
            defaults.string(forKey: Keys.bio) ?? "",
            limit: Self.bioLimit
        )
    }

    func update(displayName: String, bio: String) {
        self.displayName = Self.normalized(displayName, limit: Self.displayNameLimit)
        self.bio = Self.normalized(bio, limit: Self.bioLimit)
    }

    static func limited(_ value: String, to limit: Int) -> String {
        String(value.prefix(limit))
    }

    private static func normalized(_ value: String, limit: Int) -> String {
        limited(value, to: limit)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
