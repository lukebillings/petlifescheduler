import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase

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
        .onAppear { viewModel.syncWidgetSchedule() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                viewModel.syncWidgetSchedule()
            }
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel.preview)
}
