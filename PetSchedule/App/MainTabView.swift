import StoreKit
import SwiftUI
import UIKit
import UserNotifications

@Observable
private final class PetScheduleRoot {
    let trackStore: TrackStore
    let scheduleViewModel: ScheduleViewModel
    let homeViewModel: HomeViewModel

    init() {
        let store = TrackStore()
        let schedule = ScheduleViewModel()
        trackStore = store
        scheduleViewModel = schedule
        homeViewModel = HomeViewModel(trackStore: store, scheduleViewModel: schedule)
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var root = PetScheduleRoot()
    @State private var petsViewModel = PetsViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: root.homeViewModel)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbolName) }
                .tag(AppTab.home)

            ScheduleView(viewModel: root.scheduleViewModel, petsViewModel: petsViewModel)
                .tabItem { Label(AppTab.schedule.title, systemImage: AppTab.schedule.symbolName) }
                .tag(AppTab.schedule)

            TrackView(trackStore: root.trackStore, petsViewModel: petsViewModel)
                .tabItem { Label(AppTab.track.title, systemImage: AppTab.track.symbolName) }
                .tag(AppTab.track)

            PetsView(viewModel: petsViewModel)
                .tabItem { Label(AppTab.pets.title, systemImage: AppTab.pets.symbolName) }
                .tag(AppTab.pets)

            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbolName) }
                .tag(AppTab.settings)
        }
        .preferredColorScheme(.light)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case schedule
    case track
    case pets
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .schedule: "Schedule"
        case .track: "Track"
        case .pets: "Pets"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "pawprint.fill"
        case .schedule: "calendar"
        case .track: "checklist"
        case .pets: "hare.fill"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - Settings

/// UserDefaults key — check this before scheduling any local notifications elsewhere in the app.
enum AppNotificationPreference {
    static let storageKey = "PetSchedule.settings.notificationsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }
}

/// Replace with your published URLs and App Store ID before release.
private enum AppSettingsLinks {
    static let termsAndConditions = URL(string: "https://www.apple.com/legal/internet-services/terms/site.html")!
    static let termsOfService = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicy = URL(string: "https://www.apple.com/privacy/privacy-policy/")!
    static let appStoreWriteReview = URL(string: "https://apps.apple.com/app/id0000000000?action=write-review")!
}

struct SettingsView: View {
    @Environment(\.requestReview) private var requestReview
    @AppStorage(AppNotificationPreference.storageKey) private var notificationsEnabled = false
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: notificationToggleBinding) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "When on, PetSchedule can show alerts if you allow them in the system prompt. Turn off to stop using notifications in this app."
                        )
                        if notificationAuthStatus == .denied {
                            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                                Text("Open system Settings to change alert access")
                            }
                        }
                    }
                }

                Section {
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate the app", systemImage: "star.fill")
                    }
                    Link(destination: AppSettingsLinks.appStoreWriteReview) {
                        Label("Rate on the App Store", systemImage: "arrow.up.right.square")
                    }
                } footer: {
                    Text("In-app rating may not appear every time. Use the App Store link to leave a review once the app is published.")
                }

                Section("Legal") {
                    Link(destination: AppSettingsLinks.termsAndConditions) {
                        Label("Terms and Conditions", systemImage: "doc.text")
                    }
                    Link(destination: AppSettingsLinks.termsOfService) {
                        Label("Terms of Service", systemImage: "doc.plaintext")
                    }
                    Link(destination: AppSettingsLinks.privacyPolicy) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { refreshNotificationAuthorizationStatus() }
        }
        .preferredColorScheme(.light)
    }

    private var notificationToggleBinding: Binding<Bool> {
        Binding(
            get: { notificationsEnabled },
            set: { newValue in
                if newValue {
                    Task { await requestNotificationPermissionAndEnable() }
                } else {
                    notificationsEnabled = false
                    clearScheduledNotifications()
                    refreshNotificationAuthorizationStatus()
                }
            }
        )
    }

    private func requestNotificationPermissionAndEnable() async {
        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            granted = false
        }
        await MainActor.run {
            notificationsEnabled = granted
            refreshNotificationAuthorizationStatus()
        }
    }

    private func clearScheduledNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        Task {
            try? await center.setBadgeCount(0)
        }
    }

    private func refreshNotificationAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                notificationAuthStatus = settings.authorizationStatus
            }
        }
    }
}

#Preview("Main tabs") {
    MainTabView()
}

#Preview("Settings") {
    SettingsView()
}
