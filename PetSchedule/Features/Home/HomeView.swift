import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        TabView {
            Tab("Schedule", systemImage: "calendar") {
                ScheduleView(viewModel: viewModel)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.appPink)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
}
