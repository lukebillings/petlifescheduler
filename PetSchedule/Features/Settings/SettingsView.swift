import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var remindersEnabled = true
    @State private var completionAlerts = false
    @State private var dailySummary = true
    @State private var showingResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    Toggle("Enable reminders", isOn: $remindersEnabled)
                    Toggle("Completion alerts", isOn: $completionAlerts)
                    Toggle("Daily summary", isOn: $dailySummary)
                }

                Section("Pets") {
                    Label("Manage pets", systemImage: "pawprint.fill")
                    Label("Add new pet", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.appPink)
                }

                Section("App") {
                    Label("Version 1.0", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
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
