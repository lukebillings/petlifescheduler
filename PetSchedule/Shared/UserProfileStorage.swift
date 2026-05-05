import Foundation

enum UserProfileStorage {
    static let displayNameKey = "userDisplayName"
    static let householdRosterExtrasKey = "householdRosterExtraNames"

    static func trimmedDisplayName(using defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: displayNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func rosterExtraNames(using defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: householdRosterExtrasKey)?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    static func setRosterExtraNames(_ names: [String], using defaults: UserDefaults = .standard) {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        defaults.set(cleaned, forKey: householdRosterExtrasKey)
    }
}
