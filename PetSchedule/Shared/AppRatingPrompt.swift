import StoreKit
import UIKit

/// Prompts for an App Store rating after the user has checked off enough tasks (Apple still rate-limits when the dialog appears).
enum AppRatingPrompt {
    private static let completedCountKey = "ratingPrompt.completedTasksCount"
    private static let didPromptAfterThresholdKey = "ratingPrompt.didPromptAfterThreshold"
    private static let threshold = 20

    /// Call when the user completes a scheduled task (circle check or medicine / feed / water yes).
    static func recordTaskCompleted() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didPromptAfterThresholdKey) else { return }

        let count = defaults.integer(forKey: completedCountKey) + 1
        defaults.set(count, forKey: completedCountKey)
        guard count >= threshold else { return }

        defaults.set(true, forKey: didPromptAfterThresholdKey)

        Task { @MainActor in
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
            else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
