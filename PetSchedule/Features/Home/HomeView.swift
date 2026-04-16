import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        TabView {
            Tab("Schedule", systemImage: "calendar") {
                ScheduleView(viewModel: viewModel)
            }
            Tab("My Pets", systemImage: "pawprint.fill") {
                PetsView(viewModel: viewModel)
            }
            Tab("Analytics", systemImage: "chart.bar.fill") {
                AnalyticsView(viewModel: viewModel)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView(viewModel: viewModel)
            }
        }
        .tint(.appPink)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel.preview)
}
