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

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    LaunchSplashView {
                        showSplash = false
                    }
                } else if hasCompletedOnboarding {
                    HomeView(viewModel: homeViewModel)
                } else {
                    OnboardingView(viewModel: homeViewModel) {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .animation(.easeOut(duration: 0.35), value: showSplash)
        }
    }
}
