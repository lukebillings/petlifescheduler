import SwiftUI

/// Ordered like **Schedule → My Pets → Analytics → Settings** tab bar.
enum FeatureTutorialStep: Int, CaseIterable, Hashable {
    case schedule
    case pets
    case analytics
    case settings

    var title: String {
        switch self {
        case .schedule: return "Schedule"
        case .pets: return "My Pets"
        case .analytics: return "Analytics"
        case .settings: return "Settings"
        }
    }

    var detail: String {
        switch self {
        case .schedule:
            return "Today’s tasks and calendar live here. Add events, then use + Log for walks, meals, bathroom visits, and mood notes."
        case .pets:
            return "Keep profiles for each companion—photos, weight, height, documents, and vet details."
        case .analytics:
            return "Spot trends for medicine, feeding, and water over time. Export when you need a summary."
        case .settings:
            return "Turn on reminders, choose units and time format, and tweak how the app feels."
        }
    }

    var symbolName: String {
        switch self {
        case .schedule: return "calendar"
        case .pets: return "pawprint.fill"
        case .analytics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var nextButtonTitle: String {
        switch self {
        case .settings: return "Get started"
        default: return "Next"
        }
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
                    .font(.subheadline.weight(.semibold))
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
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(step.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

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
                            .font(.body.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.appPink, in: RoundedRectangle(cornerRadius: 27))
                    }
                    .padding(.top, 12)
                    .accessibilityHint(step == .settings ? "Closes the tour." : "Shows the next tip.")
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
