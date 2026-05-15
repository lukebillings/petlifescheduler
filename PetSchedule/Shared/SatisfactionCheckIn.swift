import Foundation
import SwiftUI
import UIKit

// MARK: - Configuration

/// Recipient for the in-app “Request a feature” mailto link. Replace with your real support address before release.
private let kSatisfactionFeedbackEmail = "support@example.com"

// MARK: - Model

enum SatisfactionPromptMilestone: Int {
    case thirdSession = 3
    case tenthSession = 10
}

/// Records how often the user brings the app to the foreground (after onboarding) and which satisfaction prompts are done.
enum SatisfactionCheckIn {
    private static let foregroundCountKey = "satisfactionCheckIn.foregroundActivationCount"
    private static let completedThirdKey = "satisfactionCheckIn.completedThirdPrompt"
    private static let completedTenthKey = "satisfactionCheckIn.completedTenthPrompt"

    static func recordForegroundActivation() {
        let d = UserDefaults.standard
        let n = d.integer(forKey: foregroundCountKey) + 1
        d.set(n, forKey: foregroundCountKey)
    }

    static func foregroundActivationCount() -> Int {
        UserDefaults.standard.integer(forKey: foregroundCountKey)
    }

    /// Next milestone prompt to show, if any (`3` before `10`).
    static func nextEligibleMilestone() -> SatisfactionPromptMilestone? {
        let d = UserDefaults.standard
        let n = foregroundActivationCount()
        if n >= SatisfactionPromptMilestone.thirdSession.rawValue, !d.bool(forKey: completedThirdKey) {
            return .thirdSession
        }
        if n >= SatisfactionPromptMilestone.tenthSession.rawValue, !d.bool(forKey: completedTenthKey) {
            return .tenthSession
        }
        return nil
    }

    static func markPromptFinished(for milestone: SatisfactionPromptMilestone) {
        let d = UserDefaults.standard
        switch milestone {
        case .thirdSession: d.set(true, forKey: completedThirdKey)
        case .tenthSession: d.set(true, forKey: completedTenthKey)
        }
    }

    static func openFeatureRequestMailComposer() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let subject = "PetLifeScheduler — feature idea"
        let body =
            """
            Hi,

            Here’s what I’m trying to do / would love to see:


            ---
            App version \(version)
            """

        guard let url = Self.mailtoURL(to: kSatisfactionFeedbackEmail, subject: subject, body: body) else { return }
        UIApplication.shared.open(url)
    }

    private static func mailtoURL(to address: String, subject: String, body: String) -> URL? {
        let raw =
            "mailto:\(address)"
            + "?subject=\(Self.pctEncode(subject) ?? "")"
            + "&body=\(Self.pctEncode(body) ?? "")"
        return URL(string: raw)
    }

    private static func pctEncode(_ s: String) -> String? {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
}

// MARK: - UI state

private enum SatisfactionSheetStep {
    case primary
    case pickGoal
    case featureRequest
}

// MARK: - Sheet

struct SatisfactionCheckInSheet: View {
    /// When non-nil, completing or dismissing this sheet marks that automatic milestone done. Settings-driven flows pass nil.
    let milestoneToPersistOnDismiss: SatisfactionPromptMilestone?
    /// Highlights the relevant tab behind the sheet (same mapping as the tab tour).
    let onHighlightTab: (FeatureTutorialStep) -> Void
    /// After the user picks a help topic, the sheet dismisses and this runs so the tip can appear on the main screen above the tab bar.
    let onPresentContextualTip: (FeatureTutorialStep) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var step: SatisfactionSheetStep = .primary

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .primary:
                    primaryPane
                case .pickGoal:
                    goalsPane
                case .featureRequest:
                    featureRequestPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
        .onAppear {
            onHighlightTab(.schedule)
        }
        .onDisappear {
            if let m = milestoneToPersistOnDismiss {
                SatisfactionCheckIn.markPromptFinished(for: m)
            }
        }
    }

    private var primaryPane: some View {
        VStack(spacing: 22) {
            Text("Quick check-in")
                .font(AppTypography.panelTitle)

            Text("Is PetLifeScheduler working well for you so far?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                Button {
                    HapticManager.impact(.light)
                    dismissFlow()
                } label: {
                    Text("Yes")
                        .font(AppTypography.primaryLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appPink, in: RoundedRectangle(cornerRadius: 26))
                }

                Button {
                    HapticManager.impact(.light)
                    step = .pickGoal
                } label: {
                    Text("Not really")
                        .font(AppTypography.primaryLabel)
                        .foregroundStyle(Color.appPink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 26)
                                .strokeBorder(Color.appPink, lineWidth: 2)
                        )
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(24)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var goalsPane: some View {
        List {
            Section {
                goalRow(
                    title: "Planning visits & logging walks or meals",
                    symbol: "calendar",
                    tutorial: .schedule
                )
                goalRow(title: "Managing pet profiles & documents", symbol: "pawprint.fill", tutorial: .pets)
                goalRow(title: "Seeing trends & analytics", symbol: "chart.bar.fill", tutorial: .analytics)
                goalRow(
                    title: "Reminders, units & app preferences",
                    symbol: "gearshape.fill",
                    tutorial: .settings
                )
                goalRow(
                    title: "Sharing pets & schedule with someone else",
                    symbol: "person.3.fill",
                    tutorial: .inviteOthers
                )
            } header: {
                Text("What are you mainly trying to do?")
                    .foregroundStyle(Color.appPink)
            }

            Section {
                Button {
                    HapticManager.impact(.light)
                    step = .featureRequest
                } label: {
                    Label("None of these — I had something else in mind", systemImage: "ellipsis.bubble")
                }
            }
        }
        .tint(Color.appPink)
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    step = .primary
                }
            }
        }
    }

    private func goalRow(title: String, symbol: String, tutorial: FeatureTutorialStep) -> some View {
        Button {
            HapticManager.impact(.light)
            onHighlightTab(tutorial)
            dismiss()
            let chosen = tutorial
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onPresentContextualTip(chosen)
            }
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    private var featureRequestPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tell us what you’re missing")
                .font(AppTypography.panelTitle)

            Text(
                "We read every note. Tap below to send a quick email — mention what you expected and what happened instead."
            )
            .font(.body)
            .foregroundStyle(.secondary)

            Button {
                HapticManager.impact(.medium)
                SatisfactionCheckIn.openFeatureRequestMailComposer()
            } label: {
                Label("Request a feature", systemImage: "envelope.fill")
                    .font(AppTypography.primaryLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.appPink, in: RoundedRectangle(cornerRadius: 26))
            }

            Button {
                HapticManager.impact(.light)
                dismissFlow()
            } label: {
                Text("Close")
                    .font(AppTypography.secondaryEmphasis)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(24)
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    step = .pickGoal
                    onHighlightTab(.schedule)
                }
            }
        }
    }

    private func dismissFlow() {
        onHighlightTab(.schedule)
        dismiss()
    }
}

/// Wrapper so `HomeView` can present `.sheet(item:)`.
enum SatisfactionCheckInPresentation: Identifiable, Equatable {
    /// Shown after the 3rd / 10th foreground session; persisted when dismissed.
    case automated(SatisfactionPromptMilestone)
    /// Opened from Settings; same UI without advancing milestone flags.
    case manualFromSettings

    var id: String {
        switch self {
        case .automated(let m): return "auto-\(m.rawValue)"
        case .manualFromSettings: return "manual-settings"
        }
    }

    var milestoneToPersistOnDismiss: SatisfactionPromptMilestone? {
        switch self {
        case .automated(let m): return m
        case .manualFromSettings: return nil
        }
    }
}
