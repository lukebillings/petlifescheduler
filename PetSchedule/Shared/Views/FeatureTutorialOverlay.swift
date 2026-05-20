import SwiftUI

/// Ordered like **Schedule → My Pets → Analytics → Settings → Invite others** (last step stays on the Settings tab).
enum FeatureTutorialStep: Int, CaseIterable, Hashable {
    case schedule
    case pets
    case analytics
    case settings
    case inviteOthers

    var title: String {
        switch self {
        case .schedule: return "Schedule"
        case .pets: return "My Pets"
        case .analytics: return "Analytics"
        case .settings: return "Settings"
        case .inviteOthers: return "Invite others"
        }
    }

    var detail: String {
        switch self {
        case .schedule:
            return "Today’s events live here. Tap Event to schedule events, routines, and reminders; use Log to add quick logs for walks, feeds, water, bathroom breaks, and mood."
        case .pets:
            return "Keep each pet’s profile with photos, weight, height, documents, and vet details."
        case .analytics:
            return "Spot trends for medicine, feeding, and water over time. Export when you need a summary."
        case .settings:
            return "Turn on reminders, choose units and time format, and tweak how the app feels."
        case .inviteOthers:
            return "Open Share with family in Settings: add them to your Apple Family for free Premium, then tap Share pets & schedule to send the link."
        }
    }

    var symbolName: String {
        switch self {
        case .schedule: return "calendar"
        case .pets: return "pawprint.fill"
        case .analytics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        case .inviteOthers: return "person.3.fill"
        }
    }

    var nextButtonTitle: String {
        switch self {
        case .inviteOthers: return "Get started"
        default: return "Next"
        }
    }
}

/// Non-interactive preview of the Household row in Settings, shown on the “Invite others” tutorial step.
private struct TutorialHouseholdSettingsRowPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In Settings, look for")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.appPink)
                    .frame(width: 30, height: 30)
                    .background(Color.appPink.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)

                Text("Household")
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Household row in Settings, opens household sharing")
    }
}

/// Compact tip anchored to the bottom of the screen after the user picks a help topic (separate from the full tab tour overlay).
struct ContextualHelpTipCard: View {
    let step: FeatureTutorialStep
    let onGotIt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: step.symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.appPink)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title)
                        .font(AppTypography.panelTitle)
                    Text(step.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if step == .inviteOthers {
                TutorialHouseholdSettingsRowPreview()
            }

            Button {
                HapticManager.impact(.medium)
                onGotIt()
            } label: {
                Text("Got it")
                    .font(AppTypography.primaryLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appPink, in: RoundedRectangle(cornerRadius: 25))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityHint(
            step == .inviteOthers
                ? "Tip for inviting others from Settings. Dismiss to keep using the app."
                : "Tip for the \(step.title) tab. Dismiss to keep using the app."
        )
    }
}

/// Full-screen tap-through tour of main tabs after onboarding paywall.
struct FeatureTutorialOverlay: View {
    @Binding var isPresented: Bool
    /// Keeps the underlying tab aligned with the current tip so the tab bar stays meaningful.
    var onHighlightTab: (FeatureTutorialStep) -> Void

    @State private var step: FeatureTutorialStep = .schedule

    var body: some View {
        ZStack {
            Color.black.opacity(0.44)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        dismissTutorial()
                    }
                    .font(AppTypography.secondaryEmphasis)
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Ends the tour and returns to the app.")
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                Spacer(minLength: 56)

                VStack(spacing: 22) {
                    Image(systemName: step.symbolName)
                        .font(.system(size: 50))
                        .foregroundStyle(Color.appPink)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    Text(step.title)
                        .font(AppTypography.panelTitle)
                        .multilineTextAlignment(.center)

                    Text(step.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if step == .inviteOthers {
                        TutorialHouseholdSettingsRowPreview()
                            .padding(.top, 4)
                    }

                    HStack(spacing: 7) {
                        ForEach(FeatureTutorialStep.allCases, id: \.self) { s in
                            Capsule()
                                .fill(s == step ? Color.appPink : Color.gray.opacity(0.28))
                                .frame(width: s == step ? 22 : 7, height: 7)
                                .animation(.spring(duration: 0.28), value: step)
                        }
                    }
                    .padding(.top, 4)

                    Button {
                        advance()
                    } label: {
                        Text(step.nextButtonTitle)
                            .font(AppTypography.primaryLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.appPink, in: RoundedRectangle(cornerRadius: 27))
                    }
                    .padding(.top, 12)
                    .accessibilityHint(step == .inviteOthers ? "Closes the tour." : "Shows the next tip.")
                }
                .padding(26)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.14), radius: 22, y: 10)
                )
                .padding(.horizontal, 22)

                Text("Tip: switch tabs anytime using the bar below.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 14)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .onAppear {
            onHighlightTab(step)
        }
        .accessibilityElement(children: .contain)
    }

    private func advance() {
        let all = FeatureTutorialStep.allCases
        guard let idx = all.firstIndex(of: step), idx + 1 < all.count else {
            dismissTutorial()
            return
        }
        HapticManager.impact(.light)
        step = all[idx + 1]
        onHighlightTab(step)
    }

    private func dismissTutorial() {
        HapticManager.impact(.medium)
        onHighlightTab(.schedule)
        withAnimation(.easeOut(duration: 0.28)) {
            isPresented = false
        }
    }
}
