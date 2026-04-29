import SwiftUI

private enum MainTab: Hashable {
    case schedule
    case pets
    case analytics
    case settings
}

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("interfaceAnimationsEnabled") private var interfaceAnimationsEnabled = true
    @State private var selectedTab: MainTab = .schedule
    @Binding private var showFeatureTutorial: Bool

    init(viewModel: HomeViewModel, showFeatureTutorial: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self._showFeatureTutorial = showFeatureTutorial
    }

    /// Slide-in UI animations when enabled in Settings and system Reduce Motion is off.
    private var effectiveInterfaceMotion: Bool {
        interfaceAnimationsEnabled && !accessibilityReduceMotion
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Schedule", systemImage: "calendar", value: MainTab.schedule) {
                ScheduleView(viewModel: viewModel)
            }
            Tab("My Pets", systemImage: "pawprint.fill", value: MainTab.pets) {
                PetsView(viewModel: viewModel)
            }
            Tab("Analytics", systemImage: "chart.bar.fill", value: MainTab.analytics) {
                AnalyticsView(viewModel: viewModel)
            }
            Tab("Settings", systemImage: "gearshape.fill", value: MainTab.settings) {
                SettingsView(viewModel: viewModel)
            }
        }
        .tint(.appPink)
        .onAppear { viewModel.syncWidgetSchedule() }
        .onChange(of: selectedTab) { _, _ in
            if !showFeatureTutorial {
                HapticManager.impact(.light)
            }
        }
        .overlay {
            if showFeatureTutorial {
                FeatureTutorialOverlay(isPresented: $showFeatureTutorial) { tutorialStep in
                    switch tutorialStep {
                    case .schedule: selectedTab = .schedule
                    case .pets: selectedTab = .pets
                    case .analytics: selectedTab = .analytics
                    case .settings: selectedTab = .settings
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                viewModel.syncWidgetSchedule()
            }
        }
        .environment(\.interfaceMotionEnabled, effectiveInterfaceMotion)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel.preview)
}
