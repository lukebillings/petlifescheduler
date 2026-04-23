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

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                HomeView(viewModel: homeViewModel)
            } else {
                OnboardingView(viewModel: homeViewModel) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}
