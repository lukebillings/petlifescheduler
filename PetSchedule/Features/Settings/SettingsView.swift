import SwiftUI
import UserNotifications
import StoreKit

/// Rounded SF Symbol used as a leading affordance in Settings rows (system “inset grouped” style).
private struct SettingsTintedSymbol: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.appPink)
            .frame(width: 30, height: 30)
            .background(Color.appPink.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: HomeViewModel
    var onLaunchFeedbackCheckIn: () -> Void

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 10
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("interfaceAnimationsEnabled") private var interfaceAnimationsEnabled = true
    @AppStorage("pinkWaveHeaderEnabled") private var pinkWaveHeaderEnabled = true
    @AppStorage("timeFormat")  private var timeFormatRaw  = "24h"
    @AppStorage("weightUnit")  private var weightUnitRaw  = "kg"
    @AppStorage("heightUnit")  private var heightUnitRaw  = "cm"

    private var timeFormat:  TimeFormat  { TimeFormat(rawValue: timeFormatRaw)   ?? .twelveHour }
    private var weightUnit:  WeightUnit  { WeightUnit(rawValue: weightUnitRaw)   ?? .kg }
    private var heightUnit:  HeightUnit  { HeightUnit(rawValue: heightUnitRaw)   ?? .cm }

    @State private var showingResetConfirm = false
    @State private var testNotificationStatusMessage: String?
    @State private var showingTestNotificationStatus = false
    @State private var notificationPermissionDenied = false
    @State private var customMinutes: Int = 15
    @State private var showCustomField = false

    init(viewModel: HomeViewModel, onLaunchFeedbackCheckIn: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onLaunchFeedbackCheckIn = onLaunchFeedbackCheckIn
    }

    private enum ReminderOption: Int, CaseIterable {
        case one = 1, ten = 10, thirty = 30, custom = -1

        var label: String {
            switch self {
            case .one:    return "1 minute before"
            case .ten:    return "10 minutes before"
            case .thirty: return "30 minutes before"
            case .custom: return "Custom"
            }
        }
    }

    private var selectedOption: ReminderOption {
        ReminderOption(rawValue: reminderMinutes) ?? .custom
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PinkWaveScreenHeader("Settings")
                List {
                Section("Notifications") {
                    Toggle(isOn: $remindersEnabled.animation()) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "bell.badge.fill")
                            Text("Enable event reminders")
                        }
                    }
                    .tint(Color.appPink)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled {
                                Task { @MainActor in
                                    let center = UNUserNotificationCenter.current()
                                    let settings = await center.notificationSettings()

                                    let granted: Bool
                                    switch settings.authorizationStatus {
                                    case .authorized, .provisional, .ephemeral:
                                        granted = true
                                    case .notDetermined:
                                        granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                                    case .denied:
                                        granted = false
                                    @unknown default:
                                        granted = false
                                    }

                                    if !granted {
                                        // Keep the UI honest: reminders cannot be enabled without OS permission.
                                        remindersEnabled = false
                                    }
                                    viewModel.syncWidgetSchedule()
                                }
                            } else {
                                viewModel.syncWidgetSchedule()
                            }
                        }

                    if notificationPermissionDenied {
                        Button {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 12) {
                                SettingsTintedSymbol(systemName: "gearshape")
                                Text("Open iOS notification settings")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    if remindersEnabled {
                        ForEach(ReminderOption.allCases, id: \.rawValue) { option in
                            Button {
                                if option == .custom {
                                    showCustomField = true
                                } else {
                                    reminderMinutes = option.rawValue
                                    showCustomField = false
                                }
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if option == .custom && selectedOption == .custom {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.appPink)
                                            .fontWeight(.semibold)
                                    } else if option != .custom && option.rawValue == reminderMinutes {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.appPink)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }

                        if showCustomField || selectedOption == .custom {
                            HStack {
                                Text("Minutes before")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("15", value: $customMinutes, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .onChange(of: customMinutes) { _, v in
                                        reminderMinutes = max(1, v)
                                    }
                            }
                        }
                    }

                    Button {
                        Task { await sendTestNotificationNow() }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "bell.and.waves.left.and.right.fill")
                            Text("Send test notification")
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .onChange(of: reminderMinutes) { _, _ in
                    viewModel.syncWidgetSchedule()
                }
                .task {
                    await refreshNotificationPermissionState()
                }

                Section {
                    Toggle(isOn: $hapticsEnabled) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "iphone.radiowaves.left.and.right")
                            Text("Haptic feedback")
                        }
                    }
                    .tint(Color.appPink)

                    Toggle(isOn: $soundEffectsEnabled) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "speaker.wave.2.fill")
                            Text("Sound effects")
                        }
                    }
                    .tint(Color.appPink)

                    Toggle(isOn: $interfaceAnimationsEnabled) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "sparkles")
                            Text("Interface animations")
                        }
                    }
                    .tint(Color.appPink)

                    Toggle(isOn: $pinkWaveHeaderEnabled) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "water.waves")
                            Text("Pink wave header")
                        }
                    }
                    .tint(Color.appPink)
                } header: {
                    Text("App")
                } footer: {
                    Text("Lists and panels slide in subtly when they load. Turn off here for less motion; Settings › Accessibility › Motion › Reduce Motion also disables these animations. You can also disable the pink wave header style across tabs.")
                }

                Section {
                    Button {
                        HapticManager.impact(.light)
                        onLaunchFeedbackCheckIn()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Quick check-in")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Say how things are going, get focused tips for Schedule, Pets, Analytics, or Settings—or send a feature idea by email.")
                }

                Section {
                    NavigationLink {
                        FamilySharingSettingsView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "person.3.fill")
                            Text("Household sharing")
                                .foregroundStyle(.primary)
                        }
                    }
                } footer: {
                    Text("Tip: Add partners, family, or roommates anytime—open Household sharing and tap Invite household members. Everyone stays on the same pets and schedules via iCloud; each person uses their own Apple ID.")
                }

                Section {
                    Link(destination: URL(string: "https://support.apple.com/guide/iphone/add-widgets-iphb8ca0114/ios")!) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "square.grid.2x2.fill")
                            Text("Widgets on Home Screen")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(AppTypography.supportingText)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("Widgets & shortcuts")
                } footer: {
                    Text("Press and hold the Home Screen or Lock Screen. Tap Edit in the top-left, tap Add Widget, search for PetSchedule, then choose a widget size you like.")
                }

                Section("Units") {
                    Picker(selection: $timeFormatRaw) {
                        ForEach([TimeFormat.twelveHour, .twentyFourHour], id: \.rawValue) { fmt in
                            Text(fmt.pickerLabel).tag(fmt.rawValue)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "clock")
                            Text("Clock")
                        }
                    }
                    .onChange(of: timeFormatRaw) { _, _ in
                        viewModel.syncWidgetSchedule()
                    }

                    Picker(selection: $weightUnitRaw) {
                        ForEach([WeightUnit.kg, .stone], id: \.rawValue) { unit in
                            Text(unit.pickerLabel).tag(unit.rawValue)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "scalemass")
                            Text("Weight")
                        }
                    }

                    Picker(selection: $heightUnitRaw) {
                        ForEach([HeightUnit.cm, .imperial], id: \.rawValue) { unit in
                            Text(unit.pickerLabel).tag(unit.rawValue)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "ruler")
                            Text("Height")
                        }
                    }
                }

                Section("Rate Us") {
                    Button {
                        if let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            AppStore.requestReview(in: scene)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "star.fill")
                            Text("Rate PetSchedule")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section("Legal") {
                    Link(destination: URL(string: "https://lukebillings.github.io/PetSchedule/privacypolicy/")!) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "hand.raised.fill")
                            Text("Privacy Policy")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(AppTypography.supportingText)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Link(destination: URL(string: "https://lukebillings.github.io/PetSchedule/termsandconditions/")!) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "doc.text.fill")
                            Text("Terms & Conditions")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(AppTypography.supportingText)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Link(destination: URL(string: "https://lukebillings.github.io/PetSchedule/termsandconditions/")!) {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "checkmark.seal.fill")
                            Text("Terms of Service")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(AppTypography.supportingText)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.body.weight(.semibold))
                                .frame(width: 30, height: 30)
                            Text("Reset & Restart Onboarding")
                        }
                    }
                } footer: {
                    Text("This will clear all pets and schedules and restart the setup flow.")
                }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshNotificationPermissionState() }
            }
            .confirmationDialog(
                "Reset all data?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset & Restart", role: .destructive) {
                    viewModel.resetAll()
                    hasCompletedOnboarding = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All pets and schedules will be deleted. This cannot be undone.")
            }
            .alert("Test notification", isPresented: $showingTestNotificationStatus, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(testNotificationStatusMessage ?? "Unable to send test notification.")
            })
        }
    }

    @MainActor
    private func sendTestNotificationNow() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let status = settings.authorizationStatus

        if status == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if !granted {
                testNotificationStatusMessage = "Notifications are disabled. Turn them on in iOS Settings to test push alerts."
                showingTestNotificationStatus = true
                return
            }
        } else if status == .denied {
            testNotificationStatusMessage = "Notifications are disabled for PetSchedule. Enable them in iOS Settings, then try again."
            showingTestNotificationStatus = true
            return
        }

        let scheduled = await ScheduleReminderScheduler.scheduleTestNotification()
        if scheduled {
            testNotificationStatusMessage = "Sent. You should see a test notification in a few seconds."
        } else {
            testNotificationStatusMessage = "Couldn’t schedule a test notification right now. Please try again."
        }
        showingTestNotificationStatus = true
    }

    @MainActor
    private func refreshNotificationPermissionState() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            notificationPermissionDenied = false
        case .denied:
            notificationPermissionDenied = true
            remindersEnabled = false
        case .notDetermined:
            notificationPermissionDenied = false
        @unknown default:
            notificationPermissionDenied = false
        }
    }
}

#Preview {
    SettingsView(viewModel: HomeViewModel.preview)
}
