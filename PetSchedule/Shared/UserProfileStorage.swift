import Foundation

enum UserProfileStorage {
    static let displayNameKey = "userDisplayName"

    static func trimmedDisplayName(using defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: displayNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
