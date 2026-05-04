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
    /// One foreground activation counted until the app enters the background (matches “opened the app again”).
    @State private var countedActivationThisSlice = false
    @State private var satisfactionPresentation: SatisfactionCheckInPresentation?
    @State private var satisfactionPromptScheduleToken = 0

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
                SettingsView(viewModel: viewModel) {
                    guard !showFeatureTutorial else { return }
                    satisfactionPresentation = .manualFromSettings
                }
            }
        }
        .tint(.appPink)
        .onAppear {
            viewModel.syncWidgetSchedule()
            consumeForegroundActivationIfNeeded()
            scheduleSatisfactionCheckInIfEligible()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                countedActivationThisSlice = false
                viewModel.syncWidgetSchedule()
            }
            if phase == .inactive {
                viewModel.syncWidgetSchedule()
            }
            if phase == .active {
                consumeForegroundActivationIfNeeded()
                scheduleSatisfactionCheckInIfEligible()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            if !showFeatureTutorial {
                HapticManager.impact(.light)
            }
        }
        .onChange(of: showFeatureTutorial) { _, showing in
            if !showing {
                PostTutorialHints.startHintBundleIfNeeded()
                scheduleSatisfactionCheckInIfEligible(delay: 0.55)
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
        .sheet(item: $satisfactionPresentation) { item in
            SatisfactionCheckInSheet(milestoneToPersistOnDismiss: item.milestoneToPersistOnDismiss) { tutorialStep in
                switch tutorialStep {
                case .schedule: selectedTab = .schedule
                case .pets: selectedTab = .pets
                case .analytics: selectedTab = .analytics
                case .settings: selectedTab = .settings
                }
            }
        }
        .transformEnvironment(\.petScheduleInterfaceMotionEnabled) { enabled in
            enabled = effectiveInterfaceMotion
        }
    }

    private func consumeForegroundActivationIfNeeded() {
        guard scenePhase == .active else { return }
        guard !countedActivationThisSlice else { return }
        countedActivationThisSlice = true
        SatisfactionCheckIn.recordForegroundActivation()
    }

    private func scheduleSatisfactionCheckInIfEligible(delay: TimeInterval = 0.65) {
        satisfactionPromptScheduleToken &+= 1
        let token = satisfactionPromptScheduleToken
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard token == satisfactionPromptScheduleToken else { return }
            guard satisfactionPresentation == nil else { return }
            guard !showFeatureTutorial else { return }
            guard let milestone = SatisfactionCheckIn.nextEligibleMilestone() else { return }
            satisfactionPresentation = SatisfactionCheckInPresentation.automated(milestone)
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel.preview)
}
