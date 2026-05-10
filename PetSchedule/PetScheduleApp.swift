import SwiftUI

@main
struct PetScheduleApp: App {
    @UIApplicationDelegateAdaptor(PetScheduleAppDelegate.self) private var appDelegate
    @State private var homeViewModel = HomeViewModel.bootstrapFromPersistence()
    /// Drives the post-onboarding hard paywall — `HomeView` only renders when this is `true`.
    /// Reads the same singleton used by the onboarding paywall so a successful purchase flips
    /// the routing immediately.
    @State private var entitlementStore = SubscriptionEntitlementStore.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    /// One-shot tour of main tabs after the onboarding paywall (same session only).
    @State private var showPostPaywallFeatureTutorial = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(viewModel: homeViewModel) {
                        showPostPaywallFeatureTutorial = true
                        hasCompletedOnboarding = true
                    }
                } else if !entitlementStore.initialCheckComplete {
                    // Brief moment on launch before StoreKit returns the user's entitlements.
                    // Render an empty background to avoid flashing the paywall for users who
                    // already have an active subscription on this Apple Account.
                    Color(.systemBackground)
                        .ignoresSafeArea()
                } else if !entitlementStore.isSubscribed {
                    // Hard gate: completed onboarding but no active subscription. The user can
                    // subscribe or restore — there is no skip path. Once the entitlement flips
                    // to true, this view is replaced by `HomeView` automatically.
                    PostOnboardingPaywallView(viewModel: homeViewModel)
                } else {
                    HomeView(viewModel: homeViewModel, showFeatureTutorial: $showPostPaywallFeatureTutorial)
                }
            }
        }
    }
}

// MARK: - Interface motion (environment + modifiers)

private struct PetScheduleInterfaceMotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Distinct name to avoid clashes with SwiftUI / Motion SDK environment keys.
    var petScheduleInterfaceMotionEnabled: Bool {
        get { self[PetScheduleInterfaceMotionEnabledKey.self] }
        set { self[PetScheduleInterfaceMotionEnabledKey.self] = newValue }
    }
}

struct SlideInRowModifier: ViewModifier {
    let index: Int

    @Environment(\.petScheduleInterfaceMotionEnabled) private var motionEnabled
    @State private var shown = false
    @State private var didSchedule = false

    func body(content: Content) -> some View {
        content
            .opacity(motionEnabled ? (shown ? 1 : 0) : 1)
            .offset(y: motionEnabled ? (shown ? 0 : 14) : 0)
            .onAppear {
                guard motionEnabled else {
                    shown = true
                    return
                }
                guard !shown else { return }
                guard !didSchedule else { return }
                didSchedule = true
                let delay = Double(min(index, 18)) * 0.045
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        shown = true
                    }
                }
            }
    }
}

struct InterfaceContentEntranceModifier: ViewModifier {
    let delay: CGFloat

    @Environment(\.petScheduleInterfaceMotionEnabled) private var motionEnabled
    @State private var shown = false
    @State private var didStart = false

    func body(content: Content) -> some View {
        content
            .opacity(motionEnabled ? (shown ? 1 : 0) : 1)
            .offset(y: motionEnabled ? (shown ? 0 : 14) : 0)
            .onAppear {
                guard motionEnabled else {
                    shown = true
                    return
                }
                guard !didStart else { return }
                didStart = true
                let d = max(0, delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    func interfaceSlideInRow(index: Int) -> some View {
        modifier(SlideInRowModifier(index: index))
    }

    func interfaceContentEntrance(delay: CGFloat = 0) -> some View {
        modifier(InterfaceContentEntranceModifier(delay: delay))
    }
}
