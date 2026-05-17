import StoreKit
import SwiftUI
import UIKit

/// Prompts for an App Store rating after the user checks off enough schedule tasks.
/// Re-shows every `promptInterval` completions until the user taps through to rate (iOS does not
/// report whether a review was actually submitted).
enum AppRatingPrompt {
    private static let completedCountKey = "ratingPrompt.completedTasksCount"
    private static let lastPromptCountKey = "ratingPrompt.lastPromptAtCount"
    private static let hasRatedKey = "ratingPrompt.hasRated"

    private static let threshold = 10
    private static let promptInterval = 10

    /// Call when the user completes a scheduled task (circle check on Today / calendar).
    /// Returns `true` when the app should present `AppRatingReviewSheet`.
    @discardableResult
    static func recordTaskCompleted() -> Bool {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hasRatedKey) else { return false }

        let count = defaults.integer(forKey: completedCountKey) + 1
        defaults.set(count, forKey: completedCountKey)

        let lastPrompt = defaults.integer(forKey: lastPromptCountKey)
        let shouldPrompt: Bool
        if lastPrompt == 0 {
            shouldPrompt = count >= threshold
        } else {
            shouldPrompt = count - lastPrompt >= promptInterval
        }
        guard shouldPrompt else { return false }

        defaults.set(count, forKey: lastPromptCountKey)
        return true
    }

    /// Stops automatic rating prompts after the user chooses to open the App Store review flow.
    static func markReviewSubmitted() {
        UserDefaults.standard.set(true, forKey: hasRatedKey)
    }

    static func presentReviewRequest() {
        Task { @MainActor in
            guard let scene = activeWindowScene else { return }
            AppStore.requestReview(in: scene)
        }
    }

    private static var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
}

// MARK: - Review sheet

struct AppRatingReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "star.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.appPink.gradient)
                .padding(.top, 8)

            Text("Enjoying PetLifeScheduler?")
                .font(AppTypography.panelTitle)
                .multilineTextAlignment(.center)

            Text("A quick App Store rating helps other pet parents find us.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                Button {
                    HapticManager.impact(.medium)
                    AppRatingPrompt.presentReviewRequest()
                    AppRatingPrompt.markReviewSubmitted()
                    dismiss()
                } label: {
                    Text("Rate on the App Store")
                        .font(AppTypography.primaryLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appPink, in: RoundedRectangle(cornerRadius: 26))
                }

                Button {
                    HapticManager.impact(.light)
                    dismiss()
                } label: {
                    Text("Maybe later")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
    }
}
