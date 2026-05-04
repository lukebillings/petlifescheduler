import Foundation

enum PostTutorialHintID: String, CaseIterable, Hashable {
    case scheduleTryEvent
    case scheduleTryLog
    case petsOpenProfileExtras
    case petsAddAnother
}

/// UserDefaults keys + reset used by `PostTutorialHints` UI and `HomeViewModel.resetAll()`.
enum PostTutorialHintPersistence {
    static let bundleKey = "postTutorialHints.bundleStarted"
    static let revisionKey = "postTutorialHints.revision"
    /// Snapshot counts when the hint bundle starts so onboarding/sample events don’t hide the “try + Event” nudge.
    static let baselineNonLogScheduleCountKey = "postTutorialHints.baseline.nonLogCount"
    static let baselineQuickLogScheduleCountKey = "postTutorialHints.baseline.quickLogCount"

    static func stateKey(_ id: PostTutorialHintID) -> String {
        "postTutorialHints.\(id.rawValue)"
    }

    static func resetForFreshInstall() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: bundleKey)
        ud.removeObject(forKey: revisionKey)
        ud.removeObject(forKey: baselineNonLogScheduleCountKey)
        ud.removeObject(forKey: baselineQuickLogScheduleCountKey)
        for id in PostTutorialHintID.allCases {
            ud.removeObject(forKey: stateKey(id))
        }
    }
}
