import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var homeViewModel = HomeViewModel()
    @State private var scheduleViewModel = SchedulePlaceholderViewModel()
    @State private var petsViewModel = PetsPlaceholderViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbolName) }
                .tag(AppTab.home)

            SchedulePlaceholderView(viewModel: scheduleViewModel)
                .tabItem { Label(AppTab.schedule.title, systemImage: AppTab.schedule.symbolName) }
                .tag(AppTab.schedule)

            PetsPlaceholderView(viewModel: petsViewModel)
                .tabItem { Label(AppTab.pets.title, systemImage: AppTab.pets.symbolName) }
                .tag(AppTab.pets)
        }
        .preferredColorScheme(.light)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case schedule
    case pets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .schedule: "Schedule"
        case .pets: "Pets"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "pawprint.fill"
        case .schedule: "calendar"
        case .pets: "hare.fill"
        }
    }
}

#Preview("Main tabs") {
    MainTabView()
}
