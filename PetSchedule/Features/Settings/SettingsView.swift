import SwiftUI
import UserNotifications
import StoreKit

@ViewBuilder
private func widgetSetupStep(_ number: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Text("\(number).")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 20, alignment: .trailing)
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

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

    @AppStorage(UserProfileStorage.displayNameKey) private var userDisplayName = ""
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
    @State private var showingPopulateDummyConfirm = false
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
                Section {
                    TextField("Your name", text: $userDisplayName)
                        .textContentType(.name)
                } header: {
                    Text("Your profile")
                } footer: {
                    Text("Same name you chose when you joined PetLifeScheduler. You can change it anytime; it appears on logs so others know who did each task.")
                }

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
                            Text("Household")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Sharing")
                } footer: {
                    Text("Open Household, then Invite someone, so partners or family see the same pets and schedule over iCloud.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        widgetSetupStep(1, "Press and hold the Home Screen or Lock Screen.")
                        widgetSetupStep(2, "Tap Edit in the top-left.")
                        widgetSetupStep(3, "Tap Add Widget.")
                        widgetSetupStep(4, "Search for PetLifeScheduler and choose a widget size you like.")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Widgets")
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
                        AppRatingPrompt.presentReviewRequest()
                        AppRatingPrompt.markReviewSubmitted()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "star.fill")
                            Text("Rate PetLifeScheduler")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section {
                    Button {
                        SatisfactionCheckIn.openSupportMailComposer()
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "envelope.fill")
                            Text("Click here to get in touch")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Got a question")
                }

                Section("Legal") {
                    Link(destination: LegalPageURLs.privacy) {
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
                    Link(destination: LegalPageURLs.termsAndConditions) {
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
                    Link(destination: LegalPageURLs.termsOfService) {
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
                    Button {
                        showingPopulateDummyConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsTintedSymbol(systemName: "pawprint.fill")
                            Text("Load sample dog, cat & fish")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Sample data")
                } footer: {
                    Text("Loads Max (dog), Luna (cat), and Nemo (fish) with schedules, logs, and history. Replaces your current pets and events.")
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
            .confirmationDialog(
                "Load sample data?",
                isPresented: $showingPopulateDummyConfirm,
                titleVisibility: .visible
            ) {
                Button("Replace with sample data") {
                    viewModel.populateWithDummyDogCatFishData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current pets and schedule will be replaced with demo data for a dog, cat, and fish.")
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
            testNotificationStatusMessage = "Notifications are disabled for PetLifeScheduler. Enable them in iOS Settings, then try again."
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
