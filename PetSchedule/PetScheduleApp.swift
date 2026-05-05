import SwiftUI

@main
struct PetScheduleApp: App {
    @UIApplicationDelegateAdaptor(PetScheduleAppDelegate.self) private var appDelegate
    @State private var homeViewModel = HomeViewModel.bootstrapFromPersistence()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true
    /// One-shot tour of main tabs after the onboarding paywall (same session only).
    @State private var showPostPaywallFeatureTutorial = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    LaunchSplashView {
                        showSplash = false
                    }
                } else if hasCompletedOnboarding {
                    HomeView(viewModel: homeViewModel, showFeatureTutorial: $showPostPaywallFeatureTutorial)
                } else {
                    OnboardingView(viewModel: homeViewModel) {
                        showPostPaywallFeatureTutorial = true
                        hasCompletedOnboarding = true
                    }
                }
            }
            .animation(.easeOut(duration: 0.35), value: showSplash)
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
