import SwiftUI

@main
struct PetScheduleApp: App {
    @State private var homeViewModel: HomeViewModel = {
        #if DEBUG
        return HomeViewModel.analyticsPreview
        #else
        return HomeViewModel()
        #endif
    }()
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
