import SwiftUI
import UserNotifications
import StoreKit

struct SettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 10
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var showingResetConfirm = false
    @State private var customMinutes: Int = 15
    @State private var showCustomField = false

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
            List {
                Section("Notifications") {
                    Toggle("Enable event reminders", isOn: $remindersEnabled.animation())
                        .tint(Color.appPink)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled {
                                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
                }

                Section("App") {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(Color.appPink)
                    Label("Version 1.0", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }

                Section("Rate Us") {
                    Button {
                        if let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                    } label: {
                        HStack {
                            Label("Rate PetSchedule", systemImage: "star.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(Color.appPink)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    Link(destination: URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review")!) {
                        HStack {
                            Label("Write a Review", systemImage: "square.and.pencil")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Legal") {
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Label("Terms & Conditions", systemImage: "doc.text.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Link(destination: URL(string: "https://example.com/tos")!) {
                        HStack {
                            Label("Terms of Service", systemImage: "checkmark.seal.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Label("Reset & Restart Onboarding", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("This will clear all pets and schedules and restart the setup flow.")
                }
            }
            .navigationTitle("Settings")
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
        }
    }
}

#Preview {
    SettingsView(viewModel: HomeViewModel.preview)
}
