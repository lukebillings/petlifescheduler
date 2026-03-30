import SwiftUI

@Observable
private final class PetScheduleRoot {
    let trackStore: TrackStore
    let homeViewModel: HomeViewModel

    init() {
        let store = TrackStore()
        trackStore = store
        homeViewModel = HomeViewModel(trackStore: store)
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var root = PetScheduleRoot()
    @State private var scheduleViewModel = ScheduleViewModel()
    @State private var petsViewModel = PetsViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: root.homeViewModel)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbolName) }
                .tag(AppTab.home)

            ScheduleView(viewModel: scheduleViewModel, petsViewModel: petsViewModel)
                .tabItem { Label(AppTab.schedule.title, systemImage: AppTab.schedule.symbolName) }
                .tag(AppTab.schedule)

            TrackView(trackStore: root.trackStore, petsViewModel: petsViewModel)
                .tabItem { Label(AppTab.track.title, systemImage: AppTab.track.symbolName) }
                .tag(AppTab.track)

            PetsView(viewModel: petsViewModel)
                .tabItem { Label(AppTab.pets.title, systemImage: AppTab.pets.symbolName) }
                .tag(AppTab.pets)
        }
        .preferredColorScheme(.light)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case schedule
    case track
    case pets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .schedule: "Schedule"
        case .track: "Track"
        case .pets: "Pets"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "pawprint.fill"
        case .schedule: "calendar"
        case .track: "checklist"
        case .pets: "hare.fill"
        }
    }
}

#Preview("Main tabs") {
    MainTabView()
}
