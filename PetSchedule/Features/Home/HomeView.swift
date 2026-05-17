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
    @State private var satisfactionContextualTip: FeatureTutorialStep?

    init(viewModel: HomeViewModel, showFeatureTutorial: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self._showFeatureTutorial = showFeatureTutorial
    }

    /// Slide-in UI animations when enabled in Settings and system Reduce Motion is off.
    private var effectiveInterfaceMotion: Bool {
        interfaceAnimationsEnabled && !accessibilityReduceMotion
    }

    @ViewBuilder
    private var mainTabView: some View {
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
    }

    var body: some View {
        mainTabView
            .tint(.appPink)
            .onAppear {
                viewModel.syncWidgetSchedule()
                consumeForegroundActivationIfNeeded()
                scheduleSatisfactionCheckInIfEligible()
            }
            .onReceive(NotificationCenter.default.publisher(for: .householdCloudShareAccepted)) { _ in
                Task { await HouseholdSyncCoordinator.shared.syncNow(viewModel) }
            }
            .task {
                await HouseholdSyncCoordinator.shared.syncNow(viewModel)
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
            .onChange(of: satisfactionPresentation) { _, newValue in
                if newValue != nil {
                    satisfactionContextualTip = nil
                }
            }
            .onChange(of: showFeatureTutorial) { _, showing in
                if showing {
                    satisfactionContextualTip = nil
                } else {
                    PostTutorialHints.startHintBundleIfNeeded()
                    scheduleSatisfactionCheckInIfEligible(delay: 0.55)
                }
            }
            .onChange(of: selectedTab) { _, _ in
                if !showFeatureTutorial {
                    HapticManager.impact(.light)
                }
            }
            .overlay(alignment: .bottom) {
                if let tip = satisfactionContextualTip, !showFeatureTutorial {
                    ContextualHelpTipCard(step: tip) {
                        withAnimation(.spring(duration: 0.35)) {
                            satisfactionContextualTip = nil
                        }
                        selectedTab = tip == .inviteOthers ? .settings : .schedule
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .animation(.spring(duration: 0.38), value: satisfactionContextualTip)
            .overlay {
                if showFeatureTutorial {
                    FeatureTutorialOverlay(isPresented: $showFeatureTutorial) { tutorialStep in
                        switch tutorialStep {
                        case .schedule: selectedTab = .schedule
                        case .pets: selectedTab = .pets
                        case .analytics: selectedTab = .analytics
                        case .settings, .inviteOthers: selectedTab = .settings
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .sheet(isPresented: $viewModel.showAppRatingPrompt) {
                AppRatingReviewSheet()
            }
            .sheet(item: $satisfactionPresentation) { item in
                SatisfactionCheckInSheet(
                    milestoneToPersistOnDismiss: item.milestoneToPersistOnDismiss,
                    onHighlightTab: { tutorialStep in
                        switch tutorialStep {
                        case .schedule: selectedTab = .schedule
                        case .pets: selectedTab = .pets
                        case .analytics: selectedTab = .analytics
                        case .settings, .inviteOthers: selectedTab = .settings
                        }
                    },
                    onPresentContextualTip: { step in
                        withAnimation(.spring(duration: 0.38)) {
                            satisfactionContextualTip = step
                        }
                    }
                )
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
            guard satisfactionContextualTip == nil else { return }
            guard !showFeatureTutorial else { return }
            guard let milestone = SatisfactionCheckIn.nextEligibleMilestone() else { return }
            satisfactionPresentation = SatisfactionCheckInPresentation.automated(milestone)
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel.preview)
}
