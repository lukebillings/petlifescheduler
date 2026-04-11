import SwiftUI

@main
struct PetScheduleApp: App {
    @State private var homeViewModel = HomeViewModel()
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
